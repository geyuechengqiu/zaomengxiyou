// Offline, version-checked scaling of the existing Wukong binary export.
// The official reader marks spatial floats; all other bytes remain unchanged.
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const work = path.join(root, '.cleanup-backup/spine-hd4x');
const runtime = path.join(work, 'runtime/node_modules/@esotericsoftware/spine-core/dist');
const spine = await import(pathToFileURL(path.join(runtime, 'index.js')));
const original = new Uint8Array(fs.readFileSync(path.join(work, 'original/wukong.skel')));
const originalAtlas = fs.readFileSync(path.join(work, 'original/wukong.atlas'), 'utf8');
const scaledAtlas = fs.readFileSync(path.join(work, 'result/wukong.atlas'), 'utf8');
function load(bytes, atlasText, scale = 1, Reader = spine.SkeletonBinary) {
  const atlas = new spine.TextureAtlas(atlasText);
  const reader = new Reader(new spine.AtlasAttachmentLoader(atlas));
  reader.scale = scale;
  return reader.readSkeletonData(bytes);
}
const before = load(original, originalAtlas);
assert.equal(before.version, '4.3.23');
assert.equal(before.constraints.length, 0, 'This tool supports the current unconstrained Wukong export only');
for (const skin of before.skins)
  for (const item of skin.getAttachments())
    assert(item.attachment instanceof spine.RegionAttachment, 'Unexpected attachment type; do not guess its binary layout');

let source = fs.readFileSync(path.join(runtime, 'SkeletonBinary.js'), 'utf8');
globalThis.__spineHdOffsets = new Map();
source = source.replaceAll(/input\.readFloat\(\) \* scale/g, 'input.readScaledFloat(scale) * scale');
for (const field of ['x', 'y', 'width', 'height']) {
  source = source.replace(`skeletonData.${field} = input.readFloat();`, `skeletonData.${field} = input.readScaledFloat(scale) * scale;`);
  // Region x/y/width/height are multiplied later, after the loader callback.
  source = source.replaceAll(`const ${field} = input.readFloat();`, `const ${field} = input.readScaledFloat(scale);`);
}
source = source.replace('    readFloat() {', `    readScaledFloat(scale) {
        const offset = this.index;
        const value = this.readFloat();
        if (scale !== 1) globalThis.__spineHdOffsets.set(offset, scale);
        return value;
    }
    readFloat() {`);
source = source.replace('return skeletonData;', 'globalThis.__spineHdEnd = input.index; return skeletonData;');
const instrumented = path.join(runtime, 'SkeletonBinary.hd4x.js');
fs.writeFileSync(instrumented, source);
const {SkeletonBinary: Marker} = await import(pathToFileURL(instrumented));
load(original, originalAtlas, 4, Marker);
assert.equal(globalThis.__spineHdEnd, original.length, 'Reader must consume the full binary');
const output = Buffer.from(original);
for (const [offset, factor] of globalThis.__spineHdOffsets) {
  assert.equal(factor, 4);
  output.writeFloatBE(output.readFloatBE(offset) * factor, offset);
}
const after = load(new Uint8Array(output), scaledAtlas);
assert.equal(after.bones.length, before.bones.length);
assert.equal(after.slots.length, before.slots.length);
assert.equal(after.skins.length, before.skins.length);
assert.equal(after.animations.length, before.animations.length);
assert.equal(after.fps, before.fps);

let maxError = 0, compared = 0;
function close(actual, expected) {
  if (!Number.isFinite(actual) && actual === expected) return; // Authored hidden/empty frames have no finite bounds.
  const error = Math.abs(actual - expected);
  assert(Number.isFinite(error));
  maxError = Math.max(maxError, error);
  assert(error < 0.001, `Geometry changed: ${actual} versus ${expected}`);
  compared++;
}
for (let i=0; i<before.bones.length; i++) {
  const a=before.bones[i], b=after.bones[i];
  assert.equal(a.name,b.name); close(b.length/4,a.length);
  for (const field of ['x','y']) close(b.setupPose[field]/4,a.setupPose[field]);
  for (const field of ['rotation','scaleX','scaleY','shearX','shearY']) close(b.setupPose[field],a.setupPose[field]);
}
for (let i=0; i<before.skins.length; i++) {
  const a=before.skins[i],b=after.skins[i]; assert.equal(a.name,b.name);
  const aa=a.getAttachments(),bb=b.getAttachments(); assert.equal(aa.length,bb.length);
  for (let j=0;j<aa.length;j++) {
    assert.equal(aa[j].attachment.name,bb[j].attachment.name);
    for (const field of ['x','y','width','height']) close(bb[j].attachment[field]/4,aa[j].attachment[field]);
    for (let k=0;k<8;k++) {
      close(bb[j].attachment.sequence.offsets[0][k]/4,aa[j].attachment.sequence.offsets[0][k]);
      close(bb[j].attachment.sequence.uvs[0][k],aa[j].attachment.sequence.uvs[0][k]);
    }
  }
}
let poseSamples=0, renderedPoseSamples=0;
// Each animation is sampled at authored 30 FPS and at intermediate times.
// World positions and drawn vertices must match after 2 -> 0.5 compensation.
for (let i=0;i<before.animations.length;i++) {
  const a=before.animations[i],b=after.animations[i];
  assert.equal(a.name,b.name); assert.equal(a.duration,b.duration);
  const first=new spine.Skeleton(before),second=new spine.Skeleton(after);
  first.setSkin('基础'); second.setSkin('基础');
  first.setScale(2,2);second.setScale(.5,.5);
  for (let frame=0;frame<=Math.ceil(a.duration*60);frame++) {
    const time=Math.min(a.duration,frame/60);
    first.setupPose();second.setupPose();
    a.apply(first,-1,time,false,null,1,spine.MixFrom.setup,false,false,false);
    b.apply(second,-1,time,false,null,1,spine.MixFrom.setup,false,false,false);
    first.updateWorldTransform(spine.Physics.none);second.updateWorldTransform(spine.Physics.none);
    for (let k=0;k<first.bones.length;k++) {
      close(second.bones[k].appliedPose.worldX,first.bones[k].appliedPose.worldX);
      close(second.bones[k].appliedPose.worldY,first.bones[k].appliedPose.worldY);
    }
    const x=first.getBoundsRect(),y=second.getBoundsRect();
    if (Number.isFinite(x.width) && x.width > 0) renderedPoseSamples++;
    for (const field of ['x','y','width','height']) close(y[field],x[field]);
    poseSamples++;
  }
}
fs.writeFileSync(path.join(work,'result/wukong.skel'),output);
// For importing into Spine itself, point the nonessential images path at the
// named HD images bundle. Runtime atlas loading does not use this path.
let cursor=8;
function varint() {
  let value=0,shift=0;
  for (;;) {const byte=output[cursor++];value|=(byte&127)<<shift;if(byte<128)return value;shift+=7;}
}
const versionLength=varint()-1;
cursor+=versionLength; // Skeleton version string.
cursor+=20; // Bounds and reference scale.
assert.equal(output[cursor++],1,'Editable images path requires nonessential data');
cursor+=4; // FPS.
const imagesStart=cursor;
const imagesLength=varint()-1;
const imagesEnd=cursor+imagesLength;
const relative=Buffer.from('./images/','utf8');
const editable=Buffer.concat([output.subarray(0,imagesStart),Buffer.from([relative.length+1]),relative,output.subarray(imagesEnd)]);
assert.equal(load(new Uint8Array(editable),scaledAtlas).imagesPath,'./images/');
fs.mkdirSync(path.join(work,'editable'),{recursive:true});
fs.writeFileSync(path.join(work,'editable/wukong_hd4x.skel'),editable);
const report={version:after.version,bones:after.bones.length,slots:after.slots.length,skins:after.skins.length,
  animations:after.animations.length,changedSpatialFloats:globalThis.__spineHdOffsets.size,poseSamples,renderedPoseSamples,compared,maxError,
  factor:4,originalNodeScale:2,newNodeScale:.5,unchangedByteLength:output.length===original.length};
fs.writeFileSync(path.join(work,'skeleton-validation.json'),JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));

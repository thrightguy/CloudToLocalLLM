// src/uuid/index.ts
var lastIds = {};
function uuid(prefix = "pui_id_") {
  if (!Object.hasOwn(lastIds, prefix)) {
    lastIds[prefix] = 0;
  }
  lastIds[prefix]++;
  return `${prefix}${lastIds[prefix]}`;
}
export {
  uuid
};
//# sourceMappingURL=index.mjs.map
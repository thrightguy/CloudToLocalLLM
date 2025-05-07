import { useId as useId$1, ref, toValue } from 'vue';

function useId(initialValue) {
  var _toValue;
  var idx = useId$1();
  var id = ref(initialValue);
  return toValue(id) || "pv_id".concat((_toValue = toValue(idx)) === null || _toValue === void 0 ? void 0 : _toValue.replaceAll(/v-|-/g, '_'));
}

export { useId };
//# sourceMappingURL=index.mjs.map

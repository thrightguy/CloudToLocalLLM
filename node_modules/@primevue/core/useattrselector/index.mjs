import { useId } from 'vue';

function useAttrSelector() {
  var prefix = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : 'pc';
  var idx = useId();
  return "".concat(prefix).concat(idx.replace('v-', '').replaceAll('-', '_'));
}

export { useAttrSelector };
//# sourceMappingURL=index.mjs.map

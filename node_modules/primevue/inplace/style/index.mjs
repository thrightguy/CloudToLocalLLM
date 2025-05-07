import { style } from '@primeuix/styles/inplace';
import BaseStyle from '@primevue/core/base/style';

var classes = {
  root: 'p-inplace p-component',
  display: function display(_ref) {
    var props = _ref.props;
    return ['p-inplace-display', {
      'p-disabled': props.disabled
    }];
  },
  content: 'p-inplace-content'
};
var InplaceStyle = BaseStyle.extend({
  name: 'inplace',
  style: style,
  classes: classes
});

export { InplaceStyle as default };
//# sourceMappingURL=index.mjs.map

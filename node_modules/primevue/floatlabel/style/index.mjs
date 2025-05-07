import { style } from '@primeuix/styles/floatlabel';
import BaseStyle from '@primevue/core/base/style';

var classes = {
  root: function root(_ref) {
    var props = _ref.props;
    return ['p-floatlabel', {
      'p-floatlabel-over': props.variant === 'over',
      'p-floatlabel-on': props.variant === 'on',
      'p-floatlabel-in': props.variant === 'in'
    }];
  }
};
var FloatLabelStyle = BaseStyle.extend({
  name: 'floatlabel',
  style: style,
  classes: classes
});

export { FloatLabelStyle as default };
//# sourceMappingURL=index.mjs.map

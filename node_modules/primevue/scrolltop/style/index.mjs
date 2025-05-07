import { style } from '@primeuix/styles/scrolltop';
import BaseStyle from '@primevue/core/base/style';

var classes = {
  root: function root(_ref) {
    var props = _ref.props;
    return ['p-scrolltop', {
      'p-scrolltop-sticky': props.target !== 'window'
    }];
  },
  icon: 'p-scrolltop-icon'
};
var ScrollTopStyle = BaseStyle.extend({
  name: 'scrolltop',
  style: style,
  classes: classes
});

export { ScrollTopStyle as default };
//# sourceMappingURL=index.mjs.map

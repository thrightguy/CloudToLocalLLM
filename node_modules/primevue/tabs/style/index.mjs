import { style } from '@primeuix/styles/tabs';
import BaseStyle from '@primevue/core/base/style';

var classes = {
  root: function root(_ref) {
    var props = _ref.props;
    return ['p-tabs p-component', {
      'p-tabs-scrollable': props.scrollable
    }];
  }
};
var TabsStyle = BaseStyle.extend({
  name: 'tabs',
  style: style,
  classes: classes
});

export { TabsStyle as default };
//# sourceMappingURL=index.mjs.map

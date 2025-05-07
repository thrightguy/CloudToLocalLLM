import { style } from '@primeuix/styles/ripple';
import BaseStyle from '@primevue/core/base/style';

var classes = {
  root: 'p-ink'
};
var RippleStyle = BaseStyle.extend({
  name: 'ripple-directive',
  style: style,
  classes: classes
});

export { RippleStyle as default };
//# sourceMappingURL=index.mjs.map

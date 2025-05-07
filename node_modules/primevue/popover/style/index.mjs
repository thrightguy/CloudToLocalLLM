import { style } from '@primeuix/styles/popover';
import BaseStyle from '@primevue/core/base/style';

var classes = {
  root: 'p-popover p-component',
  content: 'p-popover-content'
};
var PopoverStyle = BaseStyle.extend({
  name: 'popover',
  style: style,
  classes: classes
});

export { PopoverStyle as default };
//# sourceMappingURL=index.mjs.map

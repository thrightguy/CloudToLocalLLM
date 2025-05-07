import { style } from '@primeuix/styles/tooltip';
import BaseStyle from '@primevue/core/base/style';

var classes = {
  root: 'p-tooltip p-component',
  arrow: 'p-tooltip-arrow',
  text: 'p-tooltip-text'
};
var TooltipStyle = BaseStyle.extend({
  name: 'tooltip-directive',
  style: style,
  classes: classes
});

export { TooltipStyle as default };
//# sourceMappingURL=index.mjs.map

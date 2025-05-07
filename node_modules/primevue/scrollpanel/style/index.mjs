import { style } from '@primeuix/styles/scrollpanel';
import BaseStyle from '@primevue/core/base/style';

var classes = {
  root: 'p-scrollpanel p-component',
  contentContainer: 'p-scrollpanel-content-container',
  content: 'p-scrollpanel-content',
  barX: 'p-scrollpanel-bar p-scrollpanel-bar-x',
  barY: 'p-scrollpanel-bar p-scrollpanel-bar-y'
};
var ScrollPanelStyle = BaseStyle.extend({
  name: 'scrollpanel',
  style: style,
  classes: classes
});

export { ScrollPanelStyle as default };
//# sourceMappingURL=index.mjs.map

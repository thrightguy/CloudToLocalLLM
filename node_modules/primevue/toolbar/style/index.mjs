import { style } from '@primeuix/styles/toolbar';
import BaseStyle from '@primevue/core/base/style';

var classes = {
  root: 'p-toolbar p-component',
  start: 'p-toolbar-start',
  center: 'p-toolbar-center',
  end: 'p-toolbar-end'
};
var ToolbarStyle = BaseStyle.extend({
  name: 'toolbar',
  style: style,
  classes: classes
});

export { ToolbarStyle as default };
//# sourceMappingURL=index.mjs.map

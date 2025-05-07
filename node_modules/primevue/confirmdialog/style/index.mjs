import { style } from '@primeuix/styles/confirmdialog';
import BaseStyle from '@primevue/core/base/style';

var classes = {
  root: 'p-confirmdialog',
  icon: 'p-confirmdialog-icon',
  message: 'p-confirmdialog-message',
  pcRejectButton: 'p-confirmdialog-reject-button',
  pcAcceptButton: 'p-confirmdialog-accept-button'
};
var ConfirmDialogStyle = BaseStyle.extend({
  name: 'confirmdialog',
  style: style,
  classes: classes
});

export { ConfirmDialogStyle as default };
//# sourceMappingURL=index.mjs.map

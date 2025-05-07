import { style } from '@primeuix/styles/confirmpopup';
import BaseStyle from '@primevue/core/base/style';

var classes = {
  root: 'p-confirmpopup p-component',
  content: 'p-confirmpopup-content',
  icon: 'p-confirmpopup-icon',
  message: 'p-confirmpopup-message',
  footer: 'p-confirmpopup-footer',
  pcRejectButton: 'p-confirmpopup-reject-button',
  pcAcceptButton: 'p-confirmpopup-accept-button'
};
var ConfirmPopupStyle = BaseStyle.extend({
  name: 'confirmpopup',
  style: style,
  classes: classes
});

export { ConfirmPopupStyle as default };
//# sourceMappingURL=index.mjs.map

import { style } from '@primeuix/styles/orderlist';
import BaseStyle from '@primevue/core/base/style';

var classes = {
  root: 'p-orderlist p-component',
  controls: 'p-orderlist-controls'
};
var OrderListStyle = BaseStyle.extend({
  name: 'orderlist',
  style: style,
  classes: classes
});

export { OrderListStyle as default };
//# sourceMappingURL=index.mjs.map

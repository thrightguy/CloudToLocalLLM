import { style } from '@primeuix/styles/progressspinner';
import BaseStyle from '@primevue/core/base/style';

var classes = {
  root: 'p-progressspinner',
  spin: 'p-progressspinner-spin',
  circle: 'p-progressspinner-circle'
};
var ProgressSpinnerStyle = BaseStyle.extend({
  name: 'progressspinner',
  style: style,
  classes: classes
});

export { ProgressSpinnerStyle as default };
//# sourceMappingURL=index.mjs.map

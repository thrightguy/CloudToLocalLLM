import { style } from '@primeuix/styles/chip';
import BaseStyle from '@primevue/core/base/style';

var classes = {
  root: 'p-chip p-component',
  image: 'p-chip-image',
  icon: 'p-chip-icon',
  label: 'p-chip-label',
  removeIcon: 'p-chip-remove-icon'
};
var ChipStyle = BaseStyle.extend({
  name: 'chip',
  style: style,
  classes: classes
});

export { ChipStyle as default };
//# sourceMappingURL=index.mjs.map

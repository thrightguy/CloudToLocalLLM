import { style } from '@primeuix/styles/toggleswitch';
import BaseStyle from '@primevue/core/base/style';

var inlineStyles = {
  root: {
    position: 'relative'
  }
};
var classes = {
  root: function root(_ref) {
    var instance = _ref.instance,
      props = _ref.props;
    return ['p-toggleswitch p-component', {
      'p-toggleswitch-checked': instance.checked,
      'p-disabled': props.disabled,
      'p-invalid': instance.$invalid
    }];
  },
  input: 'p-toggleswitch-input',
  slider: 'p-toggleswitch-slider',
  handle: 'p-toggleswitch-handle'
};
var ToggleSwitchStyle = BaseStyle.extend({
  name: 'toggleswitch',
  style: style,
  classes: classes,
  inlineStyles: inlineStyles
});

export { ToggleSwitchStyle as default };
//# sourceMappingURL=index.mjs.map

import { style } from '@primeuix/styles/knob';
import BaseStyle from '@primevue/core/base/style';

var classes = {
  root: function root(_ref) {
    var instance = _ref.instance,
      props = _ref.props;
    return ['p-knob p-component', {
      'p-disabled': props.disabled,
      'p-invalid': instance.$invalid
    }];
  },
  range: 'p-knob-range',
  value: 'p-knob-value',
  text: 'p-knob-text'
};
var KnobStyle = BaseStyle.extend({
  name: 'knob',
  style: style,
  classes: classes
});

export { KnobStyle as default };
//# sourceMappingURL=index.mjs.map

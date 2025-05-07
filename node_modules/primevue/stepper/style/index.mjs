import { style } from '@primeuix/styles/stepper';
import BaseStyle from '@primevue/core/base/style';

var classes = {
  root: function root(_ref) {
    var props = _ref.props;
    return ['p-stepper p-component', {
      'p-readonly': props.linear
    }];
  },
  separator: 'p-stepper-separator'
};
var StepperStyle = BaseStyle.extend({
  name: 'stepper',
  style: style,
  classes: classes
});

export { StepperStyle as default };
//# sourceMappingURL=index.mjs.map

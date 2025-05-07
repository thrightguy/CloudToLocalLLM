import BaseStyle from '@primevue/core/base/style';

var classes = {
  root: function root(_ref) {
    var instance = _ref.instance;
    return ['p-splitterpanel', {
      'p-splitterpanel-nested': instance.isNested
    }];
  }
};
var SplitterPanelStyle = BaseStyle.extend({
  name: 'splitterpanel',
  classes: classes
});

export { SplitterPanelStyle as default };
//# sourceMappingURL=index.mjs.map

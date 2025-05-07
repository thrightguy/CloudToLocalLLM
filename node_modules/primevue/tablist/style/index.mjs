import BaseStyle from '@primevue/core/base/style';

var classes = {
  root: 'p-tablist',
  content: function content(_ref) {
    var instance = _ref.instance;
    return ['p-tablist-content', {
      'p-tablist-viewport': instance.$pcTabs.scrollable
    }];
  },
  tabList: 'p-tablist-tab-list',
  activeBar: 'p-tablist-active-bar',
  prevButton: 'p-tablist-prev-button p-tablist-nav-button',
  nextButton: 'p-tablist-next-button p-tablist-nav-button'
};
var TabListStyle = BaseStyle.extend({
  name: 'tablist',
  classes: classes
});

export { TabListStyle as default };
//# sourceMappingURL=index.mjs.map

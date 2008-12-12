Function.prototype.method = function(name, func) {
  this.prototype[name] = func;
  return this;
};

Function.method('curry', function() {
    var slice = Array.prototype.slice,
    args = slice.apply(arguments),
    that = this;
    return function() {
        return that.apply(null, args.concat(arguments));
    };
});

if (window.google && google.gears) {
  var locator = {
    geo: google.gears.factory.create('beta.geolocation'),
    positionOptions: { enableHighAccuracy: true },
    searchingMessage:     function() { return $('#searching'); },
    foundLocationMessage: function() { return $('#your-location'); },
    failureMessage:       function() { return $('#location-not-found'); },
    updatePosition: function(position) {
//      var that = this;
      var that = locator;
      if (position.accuracy < 800) {
        $(document).ready(function() {
            var search = that.searchingMessage();
            var found  = that.foundLocationMessage();
            that.resultsURL = '/?lat=' + position.latitude + '&lng=' + position.longitude + '&acc=' + position.accuracy;
            found.find('.accuracy').text(position.accuracy);
            found.find('.results-link').attr('href', that.resultsURL).text(that.resultsURL);
            search.hide();
            found.show();
        });
      } else {
        $(document).ready(function() {
            var search  = that.searchingMessage();
            var failure = that.failureMessage();
            failure.find('.accuracy').text(position.accuracy);
            search.hide();
            failure.show();
        });
      }
    },
    watchPosition: function() {
//                     var callback = this.updatePosition.apply.curry(this);
                     var callback = this.updatePosition;
                     this.geo.getCurrentPosition(callback, null, this.positionOptions);
                   },
    execute: function() {
               var that = this;
               that.watchPosition();
               $(document).ready(function() { 
                   that.searchingMessage().show();
               });
             }
  };
  locator.execute();
}

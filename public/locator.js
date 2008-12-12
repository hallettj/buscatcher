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
        errorMessage:         function() { return $('#error'); },
        updatePosition: function(position) {
//            var that = this;
            var that = locator;
            if (that.watchId) {
                that.geo.clearWatch(that.watchId);
            }
            $(document).ready(function() {
                var search  = that.searchingMessage();
                var found   = that.foundLocationMessage();
                var failure = that.failureMessage();
                var error   = that.errorMessage();
                if (position.accuracy < 800) {
                    that.resultsURL = '/?lat=' + position.latitude + '&lng=' + position.longitude + '&acc=' + position.accuracy;
                    found.find('.accuracy').text(position.accuracy);
                    found.find('.results-link').attr('href', that.resultsURL).text(that.resultsURL);
                    search.hide();
                    failure.hide();
                    error.hide();
                    found.show();
                } else {
                    var search  = that.searchingMessage();
                    var found  = that.foundLocationMessage();
                    var failure = that.failureMessage();
                    failure.find('.accuracy').text(position.accuracy);
                    search.hide();
                    found.hide();
                    error.hide();
                    failure.show();
                }
            });
        },
        displayError: function(error) {
//            var that = this;
            var that = locator;
            if (that.watchId) {
                that.geo.clearWatch(that.watchId);
            }
            $(document).ready(function() {
                var search = that.searchingMessage();
                var found  = that.foundLocationMessage();
                var failure = that.failureMessage();
                var error   = that.errorMessage();
                error.find('.message').text(error.message);
                search.hide();
                found.hide();
                failure.hide();
                error.show();
            });
        },
        watchPosition: function() {
//            var successCallback = this.updatePosition.apply.curry(this);
//            var errorCallback   = this.displayError.apply.curry(this);
            var successCallback = this.updatePosition;
            var errorCallback   = this.displayError;
//            this.geo.getCurrentPosition(successCallback, errorCallback, this.positionOptions);
            this.watchId = this.geo.watchPosition(successCallback, errorCallback, this.positionOptions);
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

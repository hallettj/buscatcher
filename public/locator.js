if (window.google && google.gears) {
    var locator = {
        geo: google.gears.factory.create('beta.geolocation'),
        positionOptions: { enableHighAccuracy: true },
        minAccuracy: 800,  // margin-of-error in meters
        searchingMessage:     function() { return $('#searching'); },
        foundLocationMessage: function() { return $('#your-location'); },
        failureMessage:       function() { return $('#location-not-found'); },
        errorMessage:         function() { return $('#error'); },
        updatePosition: function() {
            var that = this;
            return function(position) {
                if (that.watchId) {
                    that.geo.clearWatch(that.watchId);
                }
                $(document).ready(function() {
                    var search  = that.searchingMessage();
                    var found   = that.foundLocationMessage();
                    var failure = that.failureMessage();
                    var error   = that.errorMessage();
                    if (position.accuracy < that.minAccuracy) {
                        that.resultsURL = '/?lat=' + position.latitude + '&lng=' + position.longitude + '&acc=' + position.accuracy;
                        found.find('.accuracy').text(position.accuracy);
                        found.find('.results-link').attr('href', that.resultsURL).text(that.resultsURL);
                        search.hide();
                        failure.hide();
                        error.hide();
                        found.show();
                    } else {
                        failure.find('.accuracy').text(position.accuracy);
                        search.hide();
                        found.hide();
                        error.hide();
                        failure.show();
                    }
                });
            }
        },
        displayError: function() {
            var that = this;
            return function(error) {
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
            };
        },
        watchPosition: function() {
            var successCallback = this.updatePosition();
            var errorCallback   = this.displayError();
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

/*jslint browser: true */
/*global $ */
$(document).ready(function() {
    var d_names     = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
        now         = new Date(),
        format_time = function(time) {
            var a_p,
                hour   = time.getHours(),
                minute = time.getMinutes() + "";  // cast to string
            if (hour < 12) {
                a_p = "AM";
            } else {
                a_p = "PM";
            }
            if (hour === 0) {
                hour = 12;
            }
            if (hour > 12) {
                hour = hour - 12;
            }
            if (minute.length === 1) {
                minute = "0" + minute;
            }
            return hour + ':' + minute + ' ' + a_p;
        };
    $('.relativize').map(function(i, e) {
        var tag  = $(e),
            time = new Date(tag.text()),
            disp = format_time(time);
        if (time.getDay() != now.getDay()) {
            disp = d_names[time.getDay()] + ' ' + disp;
        }
        tag.text(disp);
    });
});

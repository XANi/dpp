function time_diff(d1, d2) {
    var seconds = d1 - d2;
    var days = Math.floor(seconds / 86400);
    seconds -= days * 86400;
    var hours = Math.floor(seconds / 3600);
    seconds -= hours * 3600;
    var minutes = Math.floor(seconds / 60);
    seconds -= minutes * 60;
    var out = seconds + 's';
    if (days > 0) {
         out = days + 'd ' + hours + 'h ' + minutes + 'm ' + seconds + 's'
    } else if (hours > 0) {
         out =  hours + 'h ' + minutes + 'm ' + seconds + 's'
    } else if (minutes > 0) {
         out = minutes + 'm ' + seconds + 's'
    }
    return out
 }

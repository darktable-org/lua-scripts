var isFullscreen = false;

var toggleFullscreen = function (ele) {
    return isFullscreen ? exitFullscreen(ele) : requestFullscreen(ele);
};

var requestFullscreen = function (ele) {
    if(isFullscreen == true) return 0 ;
    
    isFullscreen = true;
    if (ele.requestFullscreen) {
	ele.requestFullscreen();
    } else if (ele.webkitRequestFullscreen) {
	ele.webkitRequestFullscreen();
    } else if (ele.mozRequestFullScreen) {
	ele.mozRequestFullScreen();
    } else if (ele.msRequestFullscreen) {
	ele.msRequestFullscreen();
    } else {
	console.log('Fullscreen API is not supported.');
    }
};

var exitFullscreen = function () {
    if(isFullscreen == false) return 0;
    
    isFullscreen = false;
    if (document.exitFullscreen) {
	document.exitFullscreen();
    } else if (document.webkitExitFullscreen) {
	document.webkitExitFullscreen();
    } else if (document.mozCancelFullScreen) {
	document.mozCancelFullScreen();
    } else if (document.msExitFullscreen) {
	document.msExitFullscreen();
    } else {
	console.log('Fullscreen API is not supported.');
    }
};


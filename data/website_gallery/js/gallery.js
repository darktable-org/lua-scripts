/*
    copyright (c) 2025 Tino Mettler

    darktable is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    darktable is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this software.  If not, see <http://www.gnu.org/licenses/>.
*/

var scrollPosX = 0;
var scrollPosY = 0;

document.addEventListener('DOMContentLoaded', function () {
    var imageCount = 0;
    const gallery = document.getElementById('gallery');
    const viewer = document.getElementById('viewer');

    function showModal(e) {
        const thumbbox = e.target.parentElement;
        const index = [...gallery.children].indexOf(thumbbox);
        currentIndex = index;
        scrollPosX = document.documentElement.scrollLeft;
        scrollPosY = document.documentElement.scrollTop;

        gallery.style.display = 'none';
        document.getElementById('heading1').style.display = 'none';
        viewer.style.display = 'grid';
        loadSlides();
        updateCounter(currentIndex);
        updateNavigationState();
    }


    function closeModal() {
        exitFullscreen(document.documentElement);
        viewer.style.display = 'none';
        document.getElementById('heading1').style.display = 'grid';
        gallery.style.display = 'flex';
        document.documentElement.scrollTo({
	    left: scrollPosX,
            top: scrollPosY,
            behavior: "instant",
        });
    };

    function createThumbnailElement(imageObj) {
        const frame = document.createElement('div');
        frame.className = 'thumb-box';
        const framesize = 18;

        const width = parseInt(imageObj.width);
        const height = parseInt(imageObj.height);
        const sum = width + height;
        const scalefactor = sum / (framesize * 2.0);
        frame.style.width = (width / scalefactor) + 'vw';
        frame.style.height = (height / scalefactor) + 'vw';

        const img = document.createElement('img');
        img.className = 'thumb';
        img.src = imageObj.filename.replace(/images\/(.*)$/i, 'thumbnails/thumb_$1');
        img.alt = imageObj.filename;
        img.addEventListener('click', function (e) { e.stopPropagation(); showModal(e); });

        frame.appendChild(img);
        gallery.appendChild(frame);
    }

    const images = gallery_data.images;

    const title = document.getElementById('gallery-title');
    const pageTitle = document.getElementById('page-title');
    if (gallery_data.name) {
        title.textContent = gallery_data.name;
        pageTitle.textContent = gallery_data.name;
    }


    document.getElementById('close').onclick = function (e) {
        e.stopPropagation();
        closeModal();
    };

    // Keyboard navigation using left/right arrow keys
    document.onkeyup = function (e) {
        e.stopPropagation();
        switch(e.key) {
        case "Escape":
            closeModal();
            break;
        }
    };

    document.getElementById('fullscreen').onclick = function (e) {
        e.stopPropagation();
        toggleFullscreen(document.documentElement);
    };

    // Populate thumbnail gallery
    images.forEach(function (imageObj) {
        createThumbnailElement(imageObj);
    });


});

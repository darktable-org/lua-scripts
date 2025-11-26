
// DOM Elements
const container = document.querySelector('.slide-container');
const slides = {
    prev: document.getElementById('prev'),
    current: document.getElementById('current'),
    next: document.getElementById('next')
};
const prevArrow = document.getElementById('prevArrow');
const nextArrow = document.getElementById('nextArrow');

// State management
let mouseTimer = null;
let startX = 0;
let startY = 0;
let isDragging = false;
let isZoomed = false;
let isPanning = false;
let hasPanned = false;
let translateX = 0;
let translateY = 0;
let currentScale = 1;
let minX = 0;
let minY = 0;
let containerRect, imgRect;
let img;

let baseWidth, baseHeight;  // Image dimensions before zoom
let baseOffsetX, baseOffsetY;  // Image position offset before zoom (due to centering)

let scaledWidth, scaledHeight;

const images = gallery_data.images;

function updateCounter(index) {
    const counter = document.getElementById('counter');
    counter.textContent = (index + 1) + ' / ' + images.length;
}

function updateBoundaries() {
    containerRect = container.getBoundingClientRect();
    // Calculate the actual scaled dimensions based on the base (pre-zoom) size
    scaledWidth = baseWidth * currentScale;
    scaledHeight = baseHeight * currentScale;
    console.log('Boundaries:', {
        containerRect,
        scaledWidth,
        scaledHeight,
        baseWidth,
        baseHeight,
        currentScale
    });
}

function limitPanning(proposedX, proposedY) {
    // With transform-origin: 0 0 and transform: translate(tx, ty) scale(s)
    //
    // Before zoom:
    // - Image element positioned at (baseOffsetX, baseOffsetY) in container
    // - Image size is (baseWidth, baseHeight)
    //
    // After transform is applied:
    // - First, scale happens around origin (0,0) of the element: element becomes (baseWidth*s, baseHeight*s)
    // - Then translate by (tx, ty) moves the whole element
    // - Final position in viewport: element's top-left is at (baseOffsetX + tx, baseOffsetY + ty)
    // - Element's bottom-right is at (baseOffsetX + tx + scaledWidth, baseOffsetY + ty + scaledHeight)
    //
    // We want the image content edges to stay within the container while allowing original borders:
    // - Left constraint: baseOffsetX + tx >= baseOffsetX  =>  tx >= 0
    // - Right constraint: baseOffsetX + tx + scaledWidth <= containerWidth - (containerWidth - baseOffsetX - baseWidth)
    //                     baseOffsetX + tx + scaledWidth <= baseOffsetX + baseWidth
    //                     tx <= baseWidth - scaledWidth
    // - Top constraint: baseOffsetY + ty >= baseOffsetY  =>  ty >= 0
    // - Bottom constraint: baseOffsetY + ty + scaledHeight <= baseOffsetY + baseHeight
    //                      ty <= baseHeight - scaledHeight

    // Calculate limits
    const maxX = 0;
    const minX = baseWidth - scaledWidth;

    const maxY = 0;
    const minY = baseHeight - scaledHeight;

    let constrainedX = proposedX;
    let constrainedY = proposedY;

    // Apply constraints
    if (scaledWidth > baseWidth) {
        // Image wider than original - constrain panning
        constrainedX = Math.max(minX, Math.min(maxX, proposedX));
    } else {
        // Image narrower than original - center it
        constrainedX = (baseWidth - scaledWidth) / 2;
    }

    if (scaledHeight > baseHeight) {
        // Image taller than original - constrain panning
        constrainedY = Math.max(minY, Math.min(maxY, proposedY));
    } else {
        // Image shorter than original - center it
        constrainedY = (baseHeight - scaledHeight) / 2;
    }

    console.log('limitPanning:', {
        proposed: { x: proposedX, y: proposedY },
        constrained: { x: constrainedX, y: constrainedY },
        limits: { minX, maxX, minY, maxY },
        baseOffset: { x: baseOffsetX, y: baseOffsetY },
        baseSize: { w: baseWidth, h: baseHeight },
        scaledSize: { w: scaledWidth, h: scaledHeight }
    });

    return {
        x: constrainedX,
        y: constrainedY
    };
}

function handleZoom(e) {
    // If we were actually panning, don't zoom
    if (hasPanned) {
        isPanning = false;
        hasPanned = false;
        return;
    }

    // If we're zoomed and haven't panned, zoom out
    if (isZoomed) {
        img.classList.add('zooming');
        translateX = 0;
        translateY = 0;
        currentScale = 1;
        img.style.transform = 'none';
        container.classList.remove('zoomed');
        isZoomed = false;
        updateNavigationState();

        setTimeout(() => {
            img.classList.remove('zooming');
        }, 200);
        return;
    }

    // Zoom in at clicked/tapped point
    if (!isZoomed) {
        const rect = img.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;

        // Store the base (pre-zoom) dimensions and offset
        baseWidth = rect.width;
        baseHeight = rect.height;
        baseOffsetX = rect.left;
        baseOffsetY = rect.top;

        // Calculate the scale for 1:1 pixel zoom
        currentScale = img.naturalWidth / rect.width;

        // Calculate the translation needed to keep clicked point under cursor
        // After scaling, the point at (x, y) will be at (x * currentScale, y * currentScale)
        // We want it to remain at (e.clientX - rect.left, e.clientY - rect.top)
        translateX = e.clientX - rect.left - (x * currentScale);
        translateY = e.clientY - rect.top - (y * currentScale);

        updateBoundaries();
        const limited = limitPanning(translateX, translateY);
        translateX = limited.x;
        translateY = limited.y;

        img.classList.add('zooming');
        img.style.transform = `translate(${translateX}px, ${translateY}px) scale(${currentScale})`;
        container.classList.add('zoomed');

        setTimeout(() => {
            img.classList.remove('zooming');
        }, 200);
    }
    isZoomed = true;
    updateNavigationState();
}

function createImageElement(imageData) {
    if (!imageData) return null;
    const img = new Image();
    img.src = imageData.filename;
    img.width = imageData.width;
    img.height = imageData.height;
    img.addEventListener('dragstart', (e) => e.preventDefault());
    return img;
}

function loadSlides() {
    slides.prev.innerHTML = '';
    slides.current.innerHTML = '';
    slides.next.innerHTML = '';

    if (currentIndex > 0) {
        const prevImg = createImageElement(images[currentIndex - 1]);
        if (prevImg) slides.prev.appendChild(prevImg);
    }

    const currentImg = createImageElement(images[currentIndex]);
    if (currentImg) {
        img = currentImg;
        slides.current.appendChild(currentImg);
    }

    if (currentIndex < images.length - 1) {
        const nextImg = createImageElement(images[currentIndex + 1]);
        if (nextImg) slides.next.appendChild(nextImg);
    }

    updateCounter(currentIndex)
    updateNavigationState();
}

function updateNavigationState() {
    prevArrow.style.visibility = (currentIndex === 0 || isZoomed) ? 'hidden' : 'visible';
    nextArrow.style.visibility = (currentIndex === images.length - 1 || isZoomed) ? 'hidden' : 'visible';
}

async function showPreviousImage() {
    if (currentIndex > 0 && !isZoomed) {
        currentIndex--;
        container.style.transition = 'transform 0.3s ease-out';
        container.style.transform = 'translateX(0%)';
        await waitForTransition();
        container.style.transition = 'none';
        container.style.transform = 'translateX(-33.333%)';
        loadSlides();
    }
}

async function showNextImage() {
    if (currentIndex < images.length - 1 && !isZoomed) {
        currentIndex++;
        container.style.transition = 'transform 0.3s ease-out';
        container.style.transform = 'translateX(-66.666%)';
        await waitForTransition();
        container.style.transition = 'none';
        container.style.transform = 'translateX(-33.333%)';
        loadSlides();
    }
}

function handleTouchStart(e) {
    if (isZoomed) return;
    startX = e.touches[0].clientX;
    isDragging = true;
    container.style.transition = 'none';
}

function handleTouchMove(e) {
    if (!isDragging || isZoomed) return;

    const currentX = e.touches[0].clientX;
    const diff = currentX - startX;
    const baseOffset = -33.333;
    const percentMoved = (diff / window.innerWidth) * 33.333;

    container.style.transform = `translateX(${baseOffset + percentMoved}%)`;
}

async function handleTouchEnd(e) {
    if (!isDragging)
        if(isZoomed) {
            handleZoom(e);
            return;
        }
    isDragging = false;

    const endX = e.changedTouches[0].clientX;
    const diff = endX - startX;
    const threshold = window.innerWidth * 0.2;

    container.style.transition = 'transform 0.3s ease-out';

    if (diff > threshold && currentIndex > 0) {
        await showPreviousImage();
    } else if (diff < -threshold && currentIndex < images.length - 1) {
        await showNextImage();
    } else {
        container.style.transform = 'translateX(-33.333%)';
    }
}

function handleMouseMove() {
    if (isZoomed) return;

    prevArrow.classList.add('visible');
    nextArrow.classList.add('visible');

    if (mouseTimer) {
        clearTimeout(mouseTimer);
    }

    mouseTimer = setTimeout(() => {
        prevArrow.classList.remove('visible');
        nextArrow.classList.remove('visible');
    }, 1000);
}

function handleKeyDown(e) {
    if (isZoomed) return;

    if (e.code === 'Space' || e.code === 'ArrowRight') {
        e.preventDefault();
        showNextImage();
    } else if (e.code === 'Backspace' || e.code === 'ArrowLeft') {
        e.preventDefault();
        showPreviousImage();
    }
}

function waitForTransition() {
    return new Promise(resolve => {
        container.addEventListener('transitionend', resolve, { once: true });
    });
}

// Initialize
loadSlides();

// Navigation event listeners
container.addEventListener('touchstart', handleTouchStart);
container.addEventListener('touchmove', handleTouchMove);
container.addEventListener('touchend', handleTouchEnd);
container.addEventListener('click', handleZoom);

// make nav arrows visible
document.addEventListener('mousemove', handleMouseMove);

document.addEventListener('keydown', handleKeyDown);
prevArrow.addEventListener('click', showPreviousImage);
nextArrow.addEventListener('click', showNextImage);

// Mouse panning event listeners
container.addEventListener('mousedown', function(e) {
    if (isZoomed && e.target.tagName === 'IMG') {
        isPanning = true;
        hasPanned = false;
        updateBoundaries();
        startX = e.clientX - translateX;
        startY = e.clientY - translateY;
        e.preventDefault();
        container.style.cursor = 'grabbing';
    }
});

window.addEventListener('mousemove', function(e) {
    if (isPanning && isZoomed) {
        const proposedX = e.clientX - startX;
        const proposedY = e.clientY - startY;

        const limited = limitPanning(proposedX, proposedY);
        translateX = limited.x;
        translateY = limited.y;

        const img = slides.current.querySelector('img');
        img.style.transform = `translate(${translateX}px, ${translateY}px) scale(${currentScale})`;
        hasPanned = true;
    }
});

window.addEventListener('mouseup', function() {
    if (isPanning) {
        isPanning = false;
        container.style.cursor = isZoomed ? 'zoom-out' : 'zoom-in';
    }
});

// Touch panning event listeners
container.addEventListener('touchstart', function(e) {
    if (isZoomed) {
        isPanning = true;
        hasPanned = false;
        updateBoundaries();
        const touch = e.touches[0];
        startX = touch.clientX - translateX;
        startY = touch.clientY - translateY;
        e.preventDefault();
    }
});

container.addEventListener('touchmove', function(e) {
    if (isPanning && isZoomed) {
        const touch = e.touches[0];
        const proposedX = touch.clientX - startX;
        const proposedY = touch.clientY - startY;

        const limited = limitPanning(proposedX, proposedY);
        translateX = limited.x;
        translateY = limited.y;

        const img = slides.current.querySelector('img');
        img.style.transform = `translate(${translateX}px, ${translateY}px) scale(${currentScale})`;
        hasPanned = true;
        e.preventDefault();
    }
});

container.addEventListener('touchend', function(e) {
    if (isPanning) {
        isPanning = false;
        if (!hasPanned) {
            handleZoomTap(e.changedTouches[0]);
        }
    }
});

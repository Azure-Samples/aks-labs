import React, { useState, useEffect } from 'react';


const ImageRotator = ({ images }) => {
    const [currentImageIndex, setCurrentImageIndex] = useState(0);
  
    useEffect(() => {
      const interval = setInterval(() => {
        setCurrentImageIndex((prevIndex) => (prevIndex + 1) % images.length);
      }, 5000);
  
      return () => clearInterval(interval);
    }, [images.length]);
  
    return (
      <div>
        <img src={images[currentImageIndex]} alt="Rotating images" />
      </div>
    );
  };
  
  export default ImageRotator;
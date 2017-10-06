//
//  RGBToGrayScale.metal
//  RGB To GrayScale
//
//  Created by cody's macbook on 10/5/17.
//  Copyright © 2017 crank llc. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;


kernel void rgbToGrayScale(texture2d<float,access::read> inTexture[[texture(0)]],
                           texture2d<float,access::write> outTexture[[texture(1)]],
                           uint2 threadXY [[thread_position_in_grid]] ){
    const float4 rgba = inTexture.read(threadXY);
    const float3 grayPix = dot(rgba.rgb, float3(0.299,0.586,0.114));
    outTexture.write(float4(grayPix ,1.0),threadXY);
}

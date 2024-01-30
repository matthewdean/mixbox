// ==========================================================
//  MIXBOX 2.0 (c) 2022 Secret Weapons. All rights reserved. 
//  License: Creative Commons Attribution-NonCommercial 4.0  
//  Authors: Sarka Sochorova and Ondrej Jamriska             
// ==========================================================
//
//   BASIC USAGE
//
//      float3 rgb = mixbox_lerp(lut, rgb1, rgb2, t);
// 
//   MULTI-COLOR MIXING
//
//      mixbox_latent z1 = mixbox_rgb_to_latent(lut, rgb1);
//      mixbox_latent z2 = mixbox_rgb_to_latent(lut, rgb2);
//      mixbox_latent z3 = mixbox_rgb_to_latent(lut, rgb3);
// 
//      // mix 30% of rgb1, 60% of rgb2, and 10% of rgb3
//      mixbox_latent z_mix = 0.3*z1 + 0.6*z2 + 0.1*z3;
// 
//      float3 rgb_mix = mixbox_latent_to_rgb(z_mix);
// 
//   PIGMENT COLORS
//
//      Cadmium Yellow              0.996, 0.925, 0.000
//      Hansa Yellow                0.988, 0.827, 0.000
//      Cadmium Orange              1.000, 0.412, 0.000
//      Cadmium Red                 1.000, 0.153, 0.008
//      Quinacridone Magenta        0.502, 0.008, 0.180
//      Cobalt Violet               0.306, 0.000, 0.259
//      Ultramarine Blue            0.098, 0.000, 0.349
//      Cobalt Blue                 0.000, 0.129, 0.522
//      Phthalo Blue                0.051, 0.106, 0.267
//      Phthalo Green               0.000, 0.235, 0.196
//      Permanent Green             0.027, 0.427, 0.086
//      Sap Green                   0.420, 0.580, 0.016
//      Burnt Sienna                0.482, 0.282, 0.000
// 
//   LICENSING
//
//      If you want to obtain commercial license, please
//      contact us at: mixbox@scrtwpns.com
// 

#ifndef MIXBOX_INCLUDED
#define MIXBOX_INCLUDED

#include <metal_stdlib>

typedef metal::float3x3 mixbox_latent;

inline float3 mixbox_eval_polynomial(float3 c)
{
  float c0 = c[0];
  float c1 = c[1];
  float c2 = c[2];
  float c3 = 1.0 - (c0 + c1 + c2);

  float c00 = c0 * c0;
  float c11 = c1 * c1;
  float c22 = c2 * c2;
  float c01 = c0 * c1;
  float c02 = c0 * c2;
  float c12 = c1 * c2;
  float c33 = c3 * c3;

  return (c0*c00) * float3(+0.07717053, +0.02826978, +0.24832992) +
         (c1*c11) * float3(+0.95912302, +0.80256528, +0.03561839) +
         (c2*c22) * float3(+0.74683774, +0.04868586, +0.00000000) +
         (c3*c33) * float3(+0.99518138, +0.99978149, +0.99704802) +
         (c00*c1) * float3(+0.04819146, +0.83363781, +0.32515377) +
         (c01*c1) * float3(-0.68146950, +1.46107803, +1.06980936) +
         (c00*c2) * float3(+0.27058419, -0.15324870, +1.98735057) +
         (c02*c2) * float3(+0.80478189, +0.67093710, +0.18424500) +
         (c00*c3) * float3(-0.35031003, +1.37855826, +3.68865000) +
         (c0*c33) * float3(+1.05128046, +1.97815239, +2.82989073) +
         (c11*c2) * float3(+3.21607125, +0.81270228, +1.03384539) +
         (c1*c22) * float3(+2.78893374, +0.41565549, -0.04487295) +
         (c11*c3) * float3(+3.02162577, +2.55374103, +0.32766114) +
         (c1*c33) * float3(+2.95124691, +2.81201112, +1.17578442) +
         (c22*c3) * float3(+2.82677043, +0.79933038, +1.81715262) +
         (c2*c33) * float3(+2.99691099, +1.22593053, +1.80653661) +
         (c01*c2) * float3(+1.87394106, +2.05027182, -0.29835996) +
         (c01*c3) * float3(+2.56609566, +7.03428198, +0.62575374) +
         (c02*c3) * float3(+4.08329484, -1.40408358, +2.14995522) +
         (c12*c3) * float3(+6.00078678, +2.55552042, +1.90739502);
}

inline float mixbox_srgb_to_linear(float x)
{
  return (x >= 0.04045) ? metal::pow((x + 0.055) / 1.055, 2.4) : x/12.92;
}

inline float mixbox_linear_to_srgb(float x)
{
  return (x >= 0.0031308) ? 1.055*metal::pow(x, 1.0/2.4) - 0.055 : 12.92*x;
}

inline float3 mixbox_srgb_to_linear(float3 rgb)
{
  return float3(mixbox_srgb_to_linear(rgb.r),
                mixbox_srgb_to_linear(rgb.g),
                mixbox_srgb_to_linear(rgb.b));
}

inline float3 mixbox_linear_to_srgb(float3 rgb)
{
  return float3(mixbox_linear_to_srgb(rgb.r),
                mixbox_linear_to_srgb(rgb.g),
                mixbox_linear_to_srgb(rgb.b));
}

inline mixbox_latent mixbox_rgb_to_latent(metal::texture2d<float> mixbox_lut, float3 rgb)
{
#ifdef MIXBOX_COLORSPACE_LINEAR
  rgb = mixbox_linear_to_srgb(metal::saturate(rgb));
#else
  rgb = metal::saturate(rgb);
#endif

  float x = rgb.r * 63.0;
  float y = rgb.g * 63.0;
  float z = rgb.b * 63.0;

  float iz = metal::floor(z);

  float x0 = metal::fmod(iz, 8.0) * 64.0;
  float y0 = metal::floor(iz / 8.0) * 64.0;

  float x1 = metal::fmod(iz + 1.0, 8.0) * 64.0;
  float y1 = metal::floor((iz + 1.0) / 8.0) * 64.0;

  float2 uv0 = float2(x0 + x + 0.5, y0 + y + 0.5) / 512.0;
  float2 uv1 = float2(x1 + x + 0.5, y1 + y + 0.5) / 512.0;

  constexpr metal::sampler lut_sampler(metal::mag_filter::linear, metal::min_filter::linear, metal::mip_filter::none);

  if (mixbox_lut.sample(lut_sampler, float2(0.5, 0.5) / 512.0).b < 0.1)
  {
    uv0.y = 1.0 - uv0.y;
    uv1.y = 1.0 - uv1.y;
  }

  float3 c = metal::mix(mixbox_lut.sample(lut_sampler, uv0).rgb, mixbox_lut.sample(lut_sampler, uv1).rgb, z - iz);

  return mixbox_latent(c, rgb - mixbox_eval_polynomial(c), float3(0.0, 0.0, 0.0));
}

inline float3 mixbox_latent_to_rgb(mixbox_latent latent)
{
  float3 rgb = metal::saturate(mixbox_eval_polynomial(latent[0]) + latent[1]);

#ifdef MIXBOX_COLORSPACE_LINEAR
  return mixbox_srgb_to_linear(rgb);
#else
  return rgb;
#endif
}

inline float3 mixbox_lerp(metal::texture2d<float> mixbox_lut, float3 color1, float3 color2, float t)
{
  return mixbox_latent_to_rgb((1.0-t)*mixbox_rgb_to_latent(mixbox_lut, color1) + t*mixbox_rgb_to_latent(mixbox_lut, color2));
}

inline float4 mixbox_lerp(metal::texture2d<float> mixbox_lut, float4 color1, float4 color2, float t)
{
  return float4(mixbox_lerp(mixbox_lut, color1.rgb, color2.rgb, t), metal::mix(color1.a, color2.a, t));
}

#endif
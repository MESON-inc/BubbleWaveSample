
#ifndef __PERLINNOISE_CGINC__
#define __PERLINNOISE_CGINC__

float random(in float2 st)
{
    return frac(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453123);
}

float noise(in float2 st)
{
    // Splited integer and float values.
    float2 i = floor(st);
    float2 f = frac(st);

    float a = random(i + float2(0.0, 0.0));
    float b = random(i + float2(1.0, 0.0));
    float c = random(i + float2(0.0, 1.0));
    float d = random(i + float2(1.0, 1.0));

    // -2.0f^3 + 3.0f^2
    float2 u = f * f * (3.0 - 2.0 * f);

    return lerp(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(in float2 st, int octave)
{
    float v = 0.0;
    float a = 0.5;

    for (int i = 0; i < octave; i++)
    {
        v += a * noise(st);
        st = st * 2.0;
        a *= 0.5;
    }

    return v;
}

float brownMotion(float2 st, float time, out float2 q, out float2 r)
{
    int octave = 5;
    
    q = 0;
    q.x = fbm(st + 0.00, octave);
    q.y = fbm(st + 1.00, octave);

    r = 0;
    r.x = fbm(st + (4.0 * q) + float2(1.7, 9.2) + (0.15 * time), octave);
    r.y = fbm(st + (4.0 * q) + float2(8.3, 2.8) + (0.12 * time), octave);

    // やっていることは以下と同義
    // d1とd2は便宜上設定した追加パラメータ（上の例ではvec2(1.7, 9.2)などがそれ。
    // fbm(st + fbm(st + fbm(st + d1) + d2))
    // つまり、3段階のfbmで最後の係数を求めている
    float f = fbm(st + 4.0 * r, octave);

    // f^3 + 0.6f^2 + 0.5f
    return (f * f * f + (0.6 * f * f) + (0.5 * f));
}

#endif

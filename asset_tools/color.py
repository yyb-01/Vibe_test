"""CIEDE2000 equations: Sharma/Wu/Dalal, DOI 10.1002/col.20070, kL=kC=kH=1."""
import numpy as np

def lab(rgb):
    x = np.asarray(rgb, float)/255
    x = np.where(x <= .04045, x/12.92, ((x+.055)/1.055)**2.4)
    xyz = x @ np.array([[.4124564, .2126729, .0193339], [.3575761, .7151522, .1191920], [.1804375, .0721750, .9503041]])
    xyz /= [.95047, 1, 1.08883]
    f = np.where(xyz > (6/29)**3, np.cbrt(xyz), xyz/(3*(6/29)**2)+4/29)
    return np.stack((116*f[..., 1]-16, 500*(f[..., 0]-f[..., 1]), 200*(f[..., 1]-f[..., 2])), axis=-1)

def delta_e(a, b):
    a, b = np.asarray(a, float), np.asarray(b, float)
    mean = (np.hypot(a[..., 1], a[..., 2])+np.hypot(b[..., 1], b[..., 2]))/2
    g = .5*(1-np.sqrt(mean**7/(mean**7+25**7)))
    ap, bp = a[..., 1]*(1+g), b[..., 1]*(1+g)
    c1, c2 = np.hypot(ap, a[..., 2]), np.hypot(bp, b[..., 2])
    h1, h2 = np.degrees(np.arctan2(a[..., 2], ap)) % 360, np.degrees(np.arctan2(b[..., 2], bp)) % 360
    h1, h2 = np.where(c1 == 0, 0, h1), np.where(c2 == 0, 0, h2)
    zero, difference = c1*c2 == 0, h2-h1
    dh = np.where(zero, 0, np.where(difference > 180, difference-360, np.where(difference < -180, difference+360, difference)))
    dl, dc = b[..., 0]-a[..., 0], c2-c1
    dh = 2*np.sqrt(c1*c2)*np.sin(np.radians(dh/2))
    ml, mc, total = (a[..., 0]+b[..., 0])/2, (c1+c2)/2, h1+h2
    mh = np.where(zero, total, np.where(np.abs(h1-h2) <= 180, total/2, np.where(total < 360, (total+360)/2, (total-360)/2)))
    cosine = lambda x: np.cos(np.radians(x))
    t = 1-.17*cosine(mh-30)+.24*cosine(2*mh)+.32*cosine(3*mh+6)-.20*cosine(4*mh-63)
    sl, sc, sh = 1+.015*(ml-50)**2/np.sqrt(20+(ml-50)**2), 1+.045*mc, 1+.015*mc*t
    rt = -2*np.sqrt(mc**7/(mc**7+25**7))*np.sin(np.radians(60*np.exp(-((mh-275)/25)**2)))
    l, c, h = dl/sl, dc/sc, dh/sh
    return np.sqrt(np.maximum(0, l*l+c*c+h*h+rt*c*h))

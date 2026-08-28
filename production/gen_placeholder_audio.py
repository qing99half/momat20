# -*- coding: utf-8 -*-
# 生成占位音频(附录E): M1/M2 为真实 120BPM 节拍器(供 Conductor 计算拍号),
# M3/V1 静音占位。仅用标准库输出 .wav(Godot 可直接导入;真音频阶段再转 .ogg)。
import os, math, wave, struct

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "placeholder")
os.makedirs(BASE, exist_ok=True)

SR = 22050
BPM = 120.0
SEC_PER_BEAT = 60.0 / BPM  # 0.5s


def make_metronome(path, dur=60.0, freq=1000.0):
    n = int(SR * dur)
    click = int(0.05 * SR)  # 50ms click
    beat = int(SEC_PER_BEAT * SR)
    frames = bytearray()
    for i in range(n):
        idx = i % beat
        s = 0.0
        if idx < click:
            env = 1.0 - idx / click
            s = math.sin(2.0 * math.pi * freq * idx / SR) * env * 0.6
        frames += struct.pack("<h", int(s * 32767))
    w = wave.open(path, "wb")
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(bytes(frames))
    w.close()
    print("ok", os.path.basename(path))


def make_silence(path, dur=30.0):
    n = int(SR * dur)
    w = wave.open(path, "wb")
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(b"\x00\x00" * n)
    w.close()
    print("ok", os.path.basename(path))


make_metronome(os.path.join(BASE, "placeholder_M1.wav"), dur=60.0, freq=1000.0)
make_metronome(os.path.join(BASE, "placeholder_M2.wav"), dur=60.0, freq=800.0)
make_silence(os.path.join(BASE, "placeholder_M3.wav"), dur=30.0)
make_silence(os.path.join(BASE, "placeholder_V1.wav"), dur=30.0)


def make_beep(path, dur=0.2, freq=1000.0):
    # 19 音效占位:统一 0.2s 正弦"哔"(S1~S19,含"呼吸"+"心跳"两个独立音效)。真素材到位后替换。
    n = int(SR * dur)
    frames = bytearray()
    for i in range(n):
        env = 1.0 - i / n
        s = math.sin(2.0 * math.pi * freq * i / SR) * env * 0.5
        frames += struct.pack("<h", int(s * 32767))
    w = wave.open(path, "wb")
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(bytes(frames))
    w.close()
    print("ok", os.path.basename(path))


for i in range(1, 20):
    make_beep(os.path.join(BASE, "placeholder_S%d.wav" % i))
print("DONE")
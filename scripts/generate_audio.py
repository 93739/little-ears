"""Generate bundled demo narration on macOS; no API key or remote audio needed.

All text is original. These are spoken rhymes, phrases, and stories, not sung
recordings. Replace the demo recordings with licensed studio audio for release.
"""
import json
import math
from pathlib import Path
import struct
import subprocess
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 22050

# id, title, Chinese title, category, illustration, background, bilingual lines
CONTENT = [
    ("hello_sunshine", "Hello, Sunshine", "你好，小太阳", "rhymes", "sun", "F9E7AF", [
        ("Hello, sunshine. Hello, day.", "你好，阳光。你好，新的一天。"),
        ("Little birds are here to play.", "小鸟们来玩啦。"),
        ("Wave your hands and say hello.", "挥挥小手，说声你好。"),
        ("Hello, hello. Here we go!", "你好，你好。我们出发吧！"),
        ("Hello, sunshine. Hello, day.", "你好，阳光。你好，新的一天。"),
        ("Little birds are here to play.", "小鸟们来玩啦。"),
        ("Wave your hands and say hello.", "挥挥小手，说声你好。"),
        ("Hello, hello. Here we go!", "你好，你好。我们出发吧！"),
    ]),
    ("color_day", "A Colorful Day", "彩色的一天", "rhymes", "rainbow", "F4DBCE", [
        ("Red, red. A little red ball.", "红色，红色。一只红色的小球。"),
        ("Blue, blue. A sky for us all.", "蓝色，蓝色。我们头顶的天空。"),
        ("Yellow, yellow. A warm little light.", "黄色，黄色。一束温暖的光。"),
        ("Green, green. The leaves look bright.", "绿色，绿色。叶子真鲜亮。"),
        ("Red and blue, yellow and green.", "红色和蓝色，黄色和绿色。"),
        ("So many colors to be seen!", "好多好多颜色等着我们看！"),
    ]),
    ("count_with_me", "One, Two, Three", "一起数一数", "rhymes", "flowers", "E1EAD4", [
        ("One little flower in the sun.", "阳光下有一朵小花。"),
        ("Two little rabbits start to run.", "两只小兔开始跑。"),
        ("Three little birds up in a tree.", "三只小鸟在树上。"),
        ("One, two, three. Count with me!", "一、二、三。跟我一起数！"),
        ("One little flower. Two little rabbits.", "一朵小花。两只小兔。"),
        ("Three little birds. One, two, three!", "三只小鸟。一、二、三！"),
    ]),
    ("little_animals", "Little Animal Parade", "小动物来啦", "rhymes", "bunny", "E5E2F1", [
        ("A little cat says meow, meow, meow.", "一只小猫喵喵叫。"),
        ("A little dog says woof, woof, woof.", "一只小狗汪汪叫。"),
        ("A little duck says quack, quack, quack.", "一只小鸭嘎嘎叫。"),
        ("A little rabbit hops right back.", "一只小兔蹦蹦跳回来。"),
        ("Hello, cat. Hello, dog.", "你好，小猫。你好，小狗。"),
        ("Hello, duck. Hop, rabbit, hop!", "你好，小鸭。跳吧，小兔，跳吧！"),
    ]),
    ("good_morning", "Good Morning", "早安，好心情", "daily", "sun", "F9E7AF", [
        ("Good morning!", "早上好！"), ("Good morning, Mommy.", "早上好，妈妈。"),
        ("Good morning, Daddy.", "早上好，爸爸。"), ("Open your eyes.", "睁开眼睛。"),
        ("Stretch your arms.", "伸伸胳膊。"), ("Hello, sunshine!", "你好，阳光！"),
        ("Good morning. A new day is here.", "早上好。新的一天到啦。"),
    ]),
    ("yummy_fruit", "Yummy Fruit", "水果真好吃", "daily", "fruit", "F7DDCE", [
        ("Look! An apple.", "看！一个苹果。"), ("A red apple.", "一个红苹果。"),
        ("Look! A banana.", "看！一根香蕉。"), ("A yellow banana.", "一根黄香蕉。"),
        ("Would you like some fruit?", "想吃点水果吗？"), ("Yes, please.", "好的，谢谢。"),
        ("Yummy, yummy!", "真好吃，真好吃！"), ("Thank you!", "谢谢！"),
    ]),
    ("tidy_up", "Time to Tidy Up", "玩具回家啦", "daily", "rainbow", "DCEAE5", [
        ("Time to tidy up.", "该收拾啦。"), ("Here is a ball.", "这里有一个球。"),
        ("Put the ball in the box.", "把球放进盒子里。"), ("Here is a little car.", "这里有一辆小车。"),
        ("Put the car in the box.", "把小车放进盒子里。"), ("All done!", "收好啦！"),
        ("Thank you for helping.", "谢谢你来帮忙。"),
    ]),
    ("good_night", "Good Night, Little One", "晚安，小宝贝", "daily", "moon", "DFE3EF", [
        ("It is bedtime.", "该睡觉啦。"), ("Put on your pajamas.", "穿上睡衣。"),
        ("Here is your little bear.", "你的小熊在这里。"), ("Close your eyes.", "闭上眼睛。"),
        ("Good night, Mommy.", "晚安，妈妈。"), ("Good night, Daddy.", "晚安，爸爸。"),
        ("Good night, little one. Sweet dreams.", "晚安，小宝贝。做个好梦。"),
    ]),
    ("little_seed", "The Little Seed", "小种子的故事", "stories", "flowers", "E1EAD4", [
        ("Here is a little seed.", "这里有一颗小种子。"), ("The seed sleeps in the soil.", "小种子睡在泥土里。"),
        ("Drip, drop. Here comes the rain.", "滴答滴答。下雨啦。"), ("Hello, sun! The sun is warm.", "你好，太阳！阳光暖暖的。"),
        ("The little seed grows and grows.", "小种子长呀长。"), ("A little leaf peeks out.", "一片小叶子探出了头。"),
        ("Now there is a flower!", "现在，开出一朵花啦！"), ("Hello, little flower.", "你好，小花。"),
    ]),
    ("sleepy_bunny", "The Sleepy Bunny", "小兔要睡觉", "stories", "bunny", "E5E2F1", [
        ("A little bunny looks up at the moon.", "小兔抬头看着月亮。"),
        ("I am sleepy, says Bunny.", "我困啦，小兔说。"), ("Bunny finds a soft little bed.", "小兔找到一张软软的小床。"),
        ("A little bear is waiting there.", "一只小熊正在那里等它。"),
        ("Good night, Bear. Good night, Moon.", "晚安，小熊。晚安，月亮。"),
        ("Bunny closes its eyes.", "小兔闭上了眼睛。"),
        ("The little bunny is fast asleep.", "小兔甜甜地睡着了。"),
    ]),
    ("red_ball", "Where Is My Ball?", "小球在哪里", "stories", "fruit", "F7DDCE", [
        ("Bunny has a little red ball.", "小兔有一个红色的小球。"),
        ("The ball rolls away. Roll, roll, roll.", "小球滚走啦。滚呀，滚呀，滚呀。"),
        ("Where is my ball? asks Bunny.", "我的小球在哪里？小兔问。"),
        ("Is it under the chair? No.", "在椅子下面吗？没有。"),
        ("Is it behind the box? Yes!", "在盒子后面吗？找到了！"),
        ("Here is my ball!", "我的小球在这里！"), ("Bunny and Bear play together.", "小兔和小熊一起玩。"),
    ]),
    ("rainy_day", "A Little Rainy Day", "滴答下雨天", "stories", "cloud", "DDE9EB", [
        ("Drip, drop. It is raining.", "滴答滴答。下雨啦。"),
        ("Bunny puts on yellow boots.", "小兔穿上黄色的小雨靴。"),
        ("Bear has a big umbrella.", "小熊有一把大雨伞。"),
        ("Come with me, says Bear.", "跟我来吧，小熊说。"),
        ("They walk together in the rain.", "它们一起在雨中散步。"),
        ("The rain stops. Here comes the sun!", "雨停了。太阳出来啦！"),
        ("Look! A rainbow!", "看！一道彩虹！"),
    ]),
]


def silence(seconds):
    return b"\0\0" * round(seconds * RATE)


def chime():
    samples = []
    for freq in (523.25, 659.25, 783.99):
        for i in range(int(RATE * 0.22)):
            t = i / RATE
            sample = math.sin(2 * math.pi * freq * t) * math.exp(-t * 15) * 1800
            samples.append(struct.pack("<h", int(sample)))
    return b"".join(samples)


def main():
    output = ROOT / "assets" / "audio"
    output.mkdir(parents=True, exist_ok=True)
    catalog = []
    with tempfile.TemporaryDirectory() as temp:
        folder = Path(temp)
        for slug, title, subtitle, category, art, color, lines in CONTENT:
            audio = chime() + silence(0.65)
            captions = []
            for index, (english, chinese) in enumerate(lines):
                aiff, wav = folder / "voice.aiff", folder / "voice.wav"
                subprocess.run(["say", "-v", "Samantha", "-r", "125", "-o", str(aiff), english], check=True)
                subprocess.run(["afconvert", str(aiff), str(wav), "-f", "WAVE", "-d", f"LEI16@{RATE}", "-c", "1"], check=True)
                with wave.open(str(wav), "rb") as stream:
                    assert stream.getframerate() == RATE and stream.getnchannels() == 1
                    voice = stream.readframes(stream.getnframes())
                captions.append({"at": round(len(audio) / 2 / RATE, 3), "en": english, "zh": chinese})
                audio += voice + silence(1.6 if category == "stories" else 2.1)
            audio += silence(0.5)
            combined = folder / "combined.wav"
            with wave.open(str(combined), "wb") as stream:
                stream.setnchannels(1)
                stream.setsampwidth(2)
                stream.setframerate(RATE)
                stream.writeframes(audio)
            target = output / f"{slug}.m4a"
            subprocess.run(["afconvert", str(combined), str(target), "-f", "m4af", "-d", "aac", "-b", "64000"], check=True)
            catalog.append({"id": slug, "title": title, "subtitle": subtitle, "category": category,
                            "art": art, "color": color, "duration": round(len(audio) / 2 / RATE, 3),
                            "asset": f"assets/audio/{slug}.m4a", "captions": captions})
            print(f"Generated {slug}: {catalog[-1]['duration']}s", flush=True)
    (ROOT / "assets" / "catalog.json").write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()

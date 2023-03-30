package states.menus;

import openfl.utils.Assets;
import handlers.Conductor;
import flixel.system.FlxSound;
import scriptStuff.HiScript;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxStringUtil;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import states.mainstates.PlayState;
import ui.HealthIcon;
import ui.Alphabet;
import handlers.Files;
import handlers.Highscore;
import handlers.MenuItem;
import handlers.MusicBeatState;
import lime.app.Application;
import states.menus.LoadingState;
import handlers.ModDataStructures;
import handlers.ClientPrefs;
import handlers.CoolUtil;

using StringTools;

typedef FreeplaySong = {
	var name:String;
	var path:String;
	var icon:String;
	var diffs:Array<String>;
}

class FreeplayState extends MusicBeatState {
	var iconArray:Array<HealthIcon> = [];
	var songList:Array<FreeplaySong> = [];

	var curSelected:Int = 0;
	var curDifficulty:Int = 1;

	var scoreText:FlxText;
	var diffText:FlxText;
	var timeText:FlxText;
	var lerpScore:Int = 0;
	var intendedScore:Int = 0;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var curPlaying:Bool = false;

	private static var vocals:FlxSound = null;
	var songMusic:FlxSound = null;

	public var playingSong:Bool = false;

	var script:HiScript;

	var coolColors:Array<Int> = [
		0xff9271fd,
		0xff9271fd,
		0xff223344,
		0xFF941653,
		0xFFfc96d7,
		0xFFa0d1ff,
		0xffff78bf,
		0xfff6b604
	];

	var bg:FlxSprite;

	var playingIcon:Int = -1;

	override function create() {
		#if SCRIPTS_ENABLED
		script = new HiScript('states/FreeplayState');
		if (!script.isBlank && script.expr != null) {
			script.interp.scriptObject = this;
			script.interp.execute(script.expr);
		}
		script.callFunction("create");
		#end

		for (week in LoadingState.modData.weekList) {
			for (i in 0...week.songs.length) {
				songList.push({
					name: week.songs[i],
					path: week.paths[i],
					icon: week.icons[i],
					diffs: week.diffs
				});
			}
		}

		#if debug
		songList.push({
			name: "Test",
			path: "test",
			icon: "bf",
			diffs: ["Normal"]
		});
		#end

		songMusic = new FlxSound().loadEmbedded((Files.song(songList[curSelected].path + '/Inst')));
		songMusic.volume = 0;

		bg = new FlxSprite().loadGraphic(Files.image('menus/mainmenu/menuBGBlue'));
		add(bg);

		#if SCRIPTS_ENABLED
		script.callFunction("createBelowItems");
		#end

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...songList.length) {
			var song:FreeplaySong = songList[i];

			var songText:Alphabet = new Alphabet(0, (70 * i) + 30, song.name, true, false);
			songText.isMenuItem = true;
			songText.targetY = i;
			grpSongs.add(songText);

			var icon:HealthIcon = new HealthIcon(song.icon);
			icon.sprTracker = songText;
			iconArray.push(icon);
			add(icon);
		}

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat("assets/fonts/vcr.ttf", 32, FlxColor.WHITE, RIGHT);

		var scoreBG:FlxSprite = new FlxSprite(scoreText.x - 6, 0).makeGraphic(Std.int(FlxG.width * 0.35), 66, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = scoreText.font;
		add(diffText);

		add(scoreText);

		var versionShit:FlxText = new FlxText(5, FlxG.height - 36.2, 0, "v" + Application.current.meta.get('version') + "\n[M] - Mod Menu", 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);

		timeText = new FlxText(FlxG.width - 100, FlxG.height - 36.2, 0, "0:00", 12);
		timeText.scrollFactor.set();
		timeText.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeText.alpha = 0.7;
		add(timeText);

		var songLength = ((songMusic.length) / 1000);
		timeText.text = FlxStringUtil.formatTime(songLength, false);

		var bullShit:Int = 0;

		for (i in 0...iconArray.length)
			iconArray[i].alpha = 0.6;

		iconArray[curSelected].alpha = 1;

		for (item in grpSongs.members) {
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;

			if (item.targetY == 0)
				item.alpha = 1;
		}
		setDiff(Math.floor(songList[curSelected].diffs.length / 2));

		super.create();
		#if SCRIPTS_ENABLED
		script.callFunction("createPost");
		#end
	}

	override function update(elapsed:Float) {
		#if SCRIPTS_ENABLED
		script.callFunction("update");
		#end
		super.update(elapsed);

		// this might be the cause of the weird audio issues
		if (PlayState.speed != 1)
			FlxG.sound.music.time += elapsed * PlayState.speed * 100;

		if (FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;

		if (FlxG.sound.music.playing)
			Conductor.songPosition = FlxG.sound.music.time;

		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, 0.4));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;

		scoreText.text = "HIGH SCORE: " + lerpScore;

		var upP = controls.UP_P;
		var downP = controls.DOWN_P;

		if (upP)
			changeSelection(-1);
		else if (downP)
			changeSelection(1);

		if (controls.LEFT_P)
			changeDiff(-1);
		else if (controls.RIGHT_P)
			changeDiff(1);

		if (controls.BACK)
			FlxG.switchState(new MainMenuState());

		/*
			if (songList[curSelected].name != null || songList[curSelected].name != 'test')
				bg.color = FlxColor.interpolate(bg.color, coolColors[Std.parseInt(weeks[curWeek]) % coolColors.length], CoolUtil.camLerpShit(0.045));
			else
				bg.color = FlxColor.interpolate(bg.color, 0xff31B0D1, CoolUtil.camLerpShit(0.045));
		 */

		#if desktop
		if (FlxG.keys.justPressed.M) {
			persistentUpdate = false;
			openSubState(new states.etc.substates.ModSelectSubstate());
			return;
		}
		#end

		if (FlxG.keys.justPressed.ENTER) {
			#if SCRIPTS_ENABLED
			script.callFunction("selectSong");
			#end

			Highscore.diffArray = songList[curSelected].diffs; // Sorry but I DONT wanna rewrite Highscore.
			var poop:String = Highscore.formatSong(songList[curSelected].path, curDifficulty);

			PlayState.songPath = songList[curSelected].path;
			PlayState.SONG = Song.loadFromJson(poop, songList[curSelected].path);
			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = curDifficulty;
			FlxG.switchState(new PlayState());
			if (FlxG.sound.music != null)
				FlxG.sound.music.stop();
		}

		if (FlxG.keys.justPressed.SPACE) {
			#if SCRIPTS_ENABLED
			script.callFunction("playSong");
			#end

			playingSong = !playingSong;

			// destroy old vocals lmfao
			if (vocals != null) {
				vocals.stop();
				vocals.destroy();
				vocals = null;
			}

			FlxG.sound.playMusic(Files.song(songList[curSelected].path + "/Inst"));
			FlxG.sound.music.pause();
			Highscore.diffArray = songList[curSelected].diffs;

			Highscore.diffArray = songList[curSelected].diffs; // Sorry but I DONT wanna rewrite Highscore.
			var poop:String = Highscore.formatSong(songList[curSelected].path, curDifficulty);

			PlayState.songPath = songList[curSelected].path;

			if (!Assets.exists('assets/data/' + songList[curSelected].path.toLowerCase() + '/' + poop.toLowerCase() + '.json')) {
				trace('Song does not have a valid JSON! Aborting before errors occur!');
				return;
			}

			PlayState.SONG = Song.loadFromJson(poop, songList[curSelected].path);

			if (PlayState.SONG.needsVoices)
				vocals = new FlxSound().loadEmbedded((Files.song(songList[curSelected].path + '/Voices')));
			else
				vocals = new FlxSound();

			FlxG.sound.list.add(vocals);

			// mackery, have you ever heard of null checks  no
			FlxG.sound.music.play(true);

			if (vocals != null)
				vocals.play();
			vocals.persist = false;
			vocals.looped = true;

			playingIcon = curSelected;
			Conductor.changeBPM(PlayState.SONG.bpm);
			Conductor.mapBPMChanges(PlayState.SONG);
		}

		for (icon in iconArray)
			icon.scale.set(FlxMath.lerp(icon.scale.x, 1, elapsed * 9), FlxMath.lerp(icon.scale.y, 1, elapsed * 9));

		#if SCRIPTS_ENABLED
		script.callFunction("updatePost");
		#end
	}

	override function beatHit():Void {
		super.beatHit();

		#if SCRIPTS_ENABLED
		script.callFunction("beatHit");
		#end

		if (iconArray[playingIcon] != null)
			iconArray[playingIcon].scale.add(0.2, 0.2);

		#if SCRIPTS_ENABLED
		script.callFunction("beatHitPost");
		#end
	}

	function changeDiff(change:Int = 0) {
		#if SCRIPTS_ENABLED
		script.callFunction("changeDiff");
		#end

		var currentSong:FreeplaySong = songList[curSelected];

		curDifficulty += change;

		if (curDifficulty < 0)
			curDifficulty = currentSong.diffs.length - 1;
		else if (curDifficulty > currentSong.diffs.length - 1)
			curDifficulty = 0;

		intendedScore = Highscore.getScore(currentSong.path, curDifficulty);

		diffText.text = "< " + currentSong.diffs[curDifficulty].toUpperCase() + " >";
	}

	// dumb shit
	function setDiff(difficulty:Int = 1) {
		curDifficulty = difficulty;

		intendedScore = Highscore.getScore(songList[curSelected].path, curDifficulty);

		diffText.text = "< " + songList[curSelected].diffs[curDifficulty].toUpperCase() + " >";
	}

	function checkDiffs(oldDiffs:Array<String>, curDiffs:Array<String>) {
		for (i in 0...curDiffs.length) {
			if (curDiffs[i].toLowerCase() != oldDiffs[i].toLowerCase())
				return false;
		}
		return true;
	}

	function changeSelection(change:Int = 0) {
		#if SCRIPTS_ENABLED
		script.callFunction("changeSelection", [change]);
		#end

		if (change == 0)
			return;

		FlxG.sound.play(Files.sound('scrollMenu'), 0.4);

		var oldDiffs:Array<String> = songList[curSelected].diffs;
		curSelected += change;

		if (curSelected < 0)
			curSelected = songList.length - 1;
		if (curSelected >= songList.length)
			curSelected = 0;

		var currentSong:FreeplaySong = songList[curSelected];
		if (oldDiffs.length != currentSong.diffs.length || !checkDiffs(oldDiffs, currentSong.diffs))
			setDiff(Math.floor(currentSong.diffs.length / 2));

		// destroy old song playing muted lmfao
		if (songMusic != null) {
			songMusic.stop();
			songMusic.destroy();
			songMusic = null;
		}

		songMusic = new FlxSound().loadEmbedded((Files.song(songList[curSelected].path + '/Inst')));

		intendedScore = Highscore.getScore(currentSong.path, curDifficulty);

		var songLength = ((songMusic.length) / 1000);
		timeText.text = FlxStringUtil.formatTime(songLength, false);

		var bullShit:Int = 0;

		for (i in 0...iconArray.length) {
			iconArray[i].alpha = 0.6;
		}

		iconArray[curSelected].alpha = 1;

		for (item in grpSongs.members) {
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;

			if (item.targetY == 0) {
				item.alpha = 1;
			}
		}
	}
}

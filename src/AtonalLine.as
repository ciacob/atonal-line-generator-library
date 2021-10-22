package {

	import ro.ciacob.maidens.generators.GeneratorBase;
	import ro.ciacob.maidens.generators.MusicEntry;
	import ro.ciacob.maidens.generators.WeightedRandomPicker;
	import ro.ciacob.maidens.generators.constants.GeneratorBaseKeys;
	import ro.ciacob.maidens.generators.constants.duration.DurationFractions;
	import ro.ciacob.math.Fraction;
	import ro.ciacob.utils.Strings;
	import ro.ciacob.utils.Time;

	public class AtonalLine extends GeneratorBase {
		
		public function AtonalLine () {}
		
		private static const ADD_FIFTY:String = '+50Ë';
		private static const ADD_FIVE:String = '+5Ë';
		private static const ADD_ONE:String = '+1Ë';
		private static const ADD_TEN:String = '+10Ë';
		private static const AUGMENTED_FORTH:String = '4a';
		private static const BASE_PITCH_WEIGHT:int = 4;
		private static const COMMON_PITCH_WEIGHT:int = 1;
		private static const DIRECTION_DOWN:String = 'directionDown';
		private static const DIRECTION_UP:String = 'directionUp';
		private static const END_PITCH_WEIGHT:int = 2;
		private static const MAJOR_SECOND:String = '2M';
		private static const MAJOR_SEVENTH:String = '7M';
		private static const MAJOR_SIXTH:String = '6M';
		private static const MAJOR_THIRD:String = '3M';
		private static const MESSAGE_DELAY:int = 1;
		private static const MINOR_SECOND:String = '2m';
		private static const MINOR_SEVENTH:String = '7m';
		private static const MINOR_SIXTH:String = '6m';
		private static const MINOR_THIRD:String = '3m';
		private static const NOTE_TYPE:String = 'noteType';
		private static const PERFECT_FIFTH:String = '5p';
		private static const PERFECT_FOURTH:String = '4p';
		private static const PERFECT_PRIME:String = '1p';
		private static const REST_TYPE:String = 'restType';
		private static const RIGHT_NOTE_WEIGHT:Number = 0.85;
		private static const START_PITCH_WEIGHT:int = 3;
		private static const SUBTRACT_FIFTY:String = '-50Ë';
		private static const SUBTRACT_FIVE:String = '-5Ë';
		private static const SUBTRACT_ONE:String = '-1Ë';
		private static const SUBTRACT_TEN:String = '-10Ë';
		private static const WRONG_NOTE_WEIGHT:Number = 0.15;

		private var _alternateDirection:String;
		private var _analisysWindow:int = 5;
		private var _climaxPoint:Number = 0.6;
		private var _durationPicker:WeightedRandomPicker;
		private var _durationSoFar:Fraction;
		private var _durationWeightsTable:Array;
		private var _entryPicker:WeightedRandomPicker;
		private var _initialDirectionIsUp:Boolean = true;
		private var _initialDirectionWeight:Number = 0.6;
		private var _mainDirection:String;
		private var _maxAdjustment:Number = 0.8;
		private var _notePicker:WeightedRandomPicker;
		private var _notesToRestsRatio:Number = 0.85;
		private var _output:Object;
		private var _queue:Array;
		private var _skipMotionWeights:Object;
		private var _stepMotionWeights:Object;
		private var _useRests:Boolean = true;
		private var _totalDuration : Fraction = Fraction.ZERO;
		
		// Initial durations choices
		private var _durations:Array = [
			below (DurationFractions.EIGHT.toString(), ADD_FIFTY),
			below (DurationFractions.SIXTEENTH.toString(), ADD_TEN),
			below (DurationFractions.HALF.toString(), ADD_ONE)
		];
		
		// Initial skip motion interval choices
		private var _skipMotionIntervals:Array = [
			below(MAJOR_THIRD, ADD_FIFTY),
			below(AUGMENTED_FORTH, ADD_TEN),
			below(MINOR_SIXTH, ADD_ONE)
		];
		
		// Initial step motion interval choices
		private var _stepMotionIntervals:Array = [
			below(MAJOR_SECOND, ADD_FIFTY),
			below(PERFECT_PRIME, ADD_ONE)
		];

		/**
		 * @see GeneratorBase.$generate
		 */
		override public function $generate():void {			
			// 2. Get prerequisites and prepare session
			var on_ready_to_generate:Function = function(... args):void {
				_computeTargetDuration (on_duration_ready);
			}
				
			// 3. Actually generate music
			var on_duration_ready : Function = function (apiName : String, duration : String) : void {
				_totalDuration = Fraction.fromString(duration);
				var notes:Array = _generateMusic();
				_output = {};
				_output[GeneratorBaseKeys.NOTE_STREAMS] = [[_queue.concat()]];
				_clearCache();
				$notifyGenerationComplete();
			}
			
			// 1. Display banner message
			$callAPI('core_showMessage', ['Now generating, please wait...']);
			Time.delay(MESSAGE_DELAY, on_ready_to_generate);
		}

		/**
		 * @see GeneratorBase.$getOutput
		 */
		override public function $getOutput():Object {
			return {"out": _output};
		}

		[Minimum(value = "1")]
		[Maximum(value = "10")]
		[Description(value = "The number of adjacent previous notes to use when analyzing overall direction and motion.")]
		[Index(value = "10")]
		[Advanced]
		public function get analisysWindow():int {
			return _analisysWindow;
		}

		public function set analisysWindow(value:int):void {
			_analisysWindow = value;
		}

		[Minimum(value = "0")]
		[Maximum(value = "1")]
		[Description(value = "The position of the climax point, expressed as a percentage of the total duration. The general direction is likely to reverse past that point.")]
		[Index(value = "5")]
		public function get climaxPoint():Number {
			return _climaxPoint;
		}

		public function set climaxPoint(value:Number):void {
			_climaxPoint = value;
		}

		[Description(value = "The musical durations you would like the program to consider using.\n\nYou define the chances of a specific duration to be picked by adding one or more weights for it.")]
		[Index(value = "6")]
		[ListFontSize(value = 10)]
		[EditorFontSize(value = 20)]
		public function get durations():Array {
			return _durations;
		}

		public function set durations(value:Array):void {
			_durations = value;
		}

		public function get durationsSrc():Array {
			return _getDurationWeightsTable();
		}

		[Description(value = "Check to make the initial direction of the melody ascending. See also the [initialDirectionWeight] setting.")]
		[Index(value = "1")]
		public function get initialDirectionIsUp():Boolean {
			return _initialDirectionIsUp;
		}

		public function set initialDirectionIsUp(value:Boolean):void {
			_initialDirectionIsUp = value;
		}

		[Minimum(value = "0.1")]
		[Maximum(value = "0.9")]
		[Description(value = "The tendency of globally using the initial melodic direction. See also the [initialDirectionIsUp] setting.")]
		[Index(value = "2")]
		public function get initialDirectionWeight():Number {
			return _initialDirectionWeight;
		}

		public function set initialDirectionWeight(value:Number):void {
			_initialDirectionWeight = value;
		}

		[Minimum(value = "0.1")]
		[Maximum(value = "0.9")]
		[Description(value = "The amount of continuous adjustment applied to the melody.")]
		[Index(value = "11")]
		[Advanced]
		public function get maxAdjustment():Number {
			return _maxAdjustment;
		}

		public function set maxAdjustment(value:Number):void {
			_maxAdjustment = value;
		}

		[Minimum(value = "0.1")]
		[Maximum(value = "0.9")]
		[Description(value = "The tendency of using notes rather than rests.")]
		[Index(value = "4")]
		public function get notesToRestsRatio():Number {
			return _notesToRestsRatio;
		}

		public function set notesToRestsRatio(value:Number):void {
			_notesToRestsRatio = value;
		}

		[Description(value = "The musical intervals you would like the program to consider using, when it intends to generate a rather skipping (jumpy) melody.\n\nYou define the chances of a specific interval to be picked by adding one, or more weights for it.")]
		[Index(value = "9")]
		[ListFontSize(value = 10)]
		[EditorFontSize(value = 24)]
		public function get skipMotionIntervals():Array {
			return _skipMotionIntervals;
		}

		public function set skipMotionIntervals(value:Array):void {
			_skipMotionIntervals = value;
		}

		public function get skipMotionIntervalsSrc():Array {
			return _getSkipIntervalsTable();
		}

		[Description(value = "The musical intervals you would like the program to consider using, when it intends to generate a rather smooth (calm) melody.\n\nYou define the chances of a specific interval to be picked by adding one, or more weights for it.")]
		[Index(value = "8")]
		[ListFontSize(value = 10)]
		[EditorFontSize(value = 24)]
		public function get stepMotionIntervals():Array {
			return _stepMotionIntervals;
		}

		public function set stepMotionIntervals(value:Array):void {
			_stepMotionIntervals = value;
		}

		public function get stepMotionIntervalsSrc():Array {
			return _getStepIntervalsTable();
		}

		[Description(value = "Check to also include rests, or leave unchecked to only use notes.")]
		[Index(value = "3")]
		public function get useRests():Boolean {
			return _useRests;
		}

		public function set useRests(value:Boolean):void {
			_useRests = value;
		}

		private function _computeTargetDuration (callback : Function) : void {
			var sectionNames : Array = [];
			for (var i:int = 0; i < $targetsInfo.length; i++) {
				var targetInfo : Object = ($targetsInfo[i] as Object);
				if (targetInfo["dataType"] == "section") {
					var name : String = targetInfo["uniqueSectionName"];	
					sectionNames.push(name);
				}
			}
			$callAPI ('core_getGreatestDurationOf', [sectionNames], callback);
		}
		
		private function _buildWeightsTable(list:Array):Object {
			var table:Object = {};
			for (var i:int = 0; i < list.length; i++) {
				var rawValue : Object = (list[i] as Object);
				var value:String = ('label' in rawValue)? rawValue.label : rawValue.toString();
				var segments:Array = _split(value);
				var key:String = (segments[0] as String);
				if (!key in table) {
					table[key] = 0;
				}
				var currWeight:Number = (table[key] as Number);
				var weight:Number = _getNumericValue(segments[1] as String);
				currWeight += weight;
				table[key] = currWeight;
			}
			return table;
		}
		
		private function _computeCompletedPercent():Number {
			return _durationSoFar.getPercentageOf(_totalDuration);
		}

		/**
		 * The purpose of a "direction adjustment" is to attempt to limit the chances for a
		 * "scale like" melody. This function "escapes" the main direction, ocasionally
		 * causing the melody to go down when it "generally" goes up, or viceversa.
		 *
		 * This is done by observing the last generated notes, and their relative position
		 * to each other.
		 *
		 * The algorythm is described below:
		 * 1. 	Collect at most `_analisysWindow` elements from the queue, starting
		 * 	    with the last and stop before the first unpitched element.
		 *
		 * 2.	Initialize two variables, `unsignedDisplacement` and `signedDisplacement`.
		 * 	    Starting with the first collected note, subtract the next note's pitch
		 * 		from current note's pitch; continue, until we exhaust all collected notes;
		 * 		consolidate values in unsigned form in `unsignedDisplacement`, and in
		 * 		signed form in `signedDisplacement`.
		 *
		 * 3.	Compute the ratio between `signedDisplacement` and `unsignedDisplacement`
		 * 		(this will retain the `signedDisplacement`s sign).
		 *
		 * 4. 	Resolve the ratio against `_maxAdjustment`, flip the sign, and return
		 * 		the obtained value.
		 */
		private function _computeDirectionAdjustment():Number {
			var unsignedDisplacement:Number = 0;
			var signedDisplacement:Number = 0;
			var analisysQueue:Array = [];
			var queueCopy:Array = _queue.concat();
			var note:MusicEntry = null;
			while (queueCopy.length > 0 && analisysQueue.length <= _analisysWindow) {
				note = queueCopy.pop() as MusicEntry;
				if (!_isPitched(note)) {
					break;
				}
				analisysQueue.push(note);
			}
			while (analisysQueue.length > 0) {
				note = analisysQueue.shift();
				var prevNote:MusicEntry = (analisysQueue.length > 0) ? (analisysQueue[0] as
					MusicEntry) : null;
				if (note != null && prevNote != null) {
					var pitch:int = note.pitch;
					var prevPitch:int = prevNote.pitch;
					var delta:int = (pitch - prevPitch);
					unsignedDisplacement += Math.abs(delta);
					signedDisplacement += delta;
				}
			}
			if (unsignedDisplacement > 0) {
				var displacementRatio:Number = (signedDisplacement / unsignedDisplacement);
				var directionAdjustment:Number = (displacementRatio * _maxAdjustment);
				return (directionAdjustment * -1);
			}
			return 0;
		}

		private function _generateMusic():Array {
			_queue = [];
			_durationSoFar = new Fraction(0);
			_stepMotionWeights = {};
			_skipMotionWeights = {};
			var completedPercent:Number = 0;
			var generatedNote:MusicEntry = null;
			while (_noteFits(generatedNote = _generateNextNote())) {
				_queue.push(generatedNote);
			}
			return _queue;
		}

		private function _generateNextNote():MusicEntry {
			if (_entryPicker == null) {
				_entryPicker = _rebuildEntryPicker();
			}
			if (_durationPicker == null) {
				_durationPicker = _rebuildDurationPicker();
			}
			_notePicker = _rebuildNotePicker();
			var note:MusicEntry = null;
			if (_queue.length == 0) {
				note = _makeInitialEntry();
			} else {
				note = _makeSubsequentEntry();
			}
			_durationSoFar = _durationSoFar.add(note.duration) as Fraction;
			return note;
		}

		private function _getBasePitch():int {
			// TODO: implement properly
			return MusicEntry.MIDDLE_C;
		}

		private function _getDurationWeightsTable():Array {
			if (_durationWeightsTable == null) {
				_durationWeightsTable = createCombinations([DurationFractions.WHOLE.
					toString(), DurationFractions.HALF.toString(), DurationFractions.
					QUARTER.toString(), DurationFractions.EIGHT.toString(), DurationFractions.
					SIXTEENTH.toString()], [SUBTRACT_FIFTY, SUBTRACT_TEN, SUBTRACT_FIVE,
					SUBTRACT_ONE, ADD_ONE, ADD_FIVE, ADD_TEN, ADD_FIFTY]);
			}
			return _durationWeightsTable;
		}

		private function _getGreatestIntervalAsSemitones(weightsTable:Object):int {
			var maxSemitones:int = 0;
			for (var intervalName:String in weightsTable) {
				var numSemitones:int = _getNumSemitones(intervalName);
				if (numSemitones > maxSemitones) {
					maxSemitones = numSemitones;
				}
			}
			return maxSemitones;
		}

		/**
		 * This function's purpose is to switch between the two available interval sets
		 * ("step motion intervals" and "skip motion intervals") when needed.
		 *
		 * A melody using too much skip motion (disjoint intervals) tends to be
		 * incomprehensible, while one using too much step motion (adjoint intervals)
		 * tends to be uninteresting.
		 *
		 * The algorithm is described below:
		 *
		 * 1. Consider the smallest available as the minimum expected displacement,
		 *    and the greatest interval available as the maximum displacement
		 *    possible. We half this value and consolidate it as `skipMotionThreshold`.
		 *
		 * 2. Collect at most `_analisysWindow` elements from the queue, starting with the
		 *    last and stop before the first unpitched element.
		 *
		 * 3. Initialize a counter, `signedDisplacement`. Starting with the first collected
		 * 	  element, subtract the next element's pitch from the current's one; continue,
		 *    until we exhaust all collected elements; consolidate the value as
		 *    `signedDisplacement`.
		 *
		 * 4. Compare the absolute (unsigned) value of `signedDisplacement` with the
		 *    `skipMotionThreshold` value. Choose step motion if  the result is
		 *    greater than or equal, or skip motion otherwise.
		 */
		private function _getIntervalWeights():Object {
			var analisysQueue:Array = [];
			var queueCopy:Array = _queue.concat();
			while (queueCopy.length > 0 && analisysQueue.length <= _analisysWindow) {
				var tmp:MusicEntry = (queueCopy.pop() as MusicEntry);
				if (!_isPitched(tmp)) {
					break;
				}
				analisysQueue.push(tmp);
			}
			if (analisysQueue.length >= 0) {
				var actualAnalysisWindow:int = analisysQueue.length;
				_stepMotionWeights = _buildWeightsTable(_stepMotionIntervals);
				_skipMotionWeights = _buildWeightsTable(_skipMotionIntervals);
				var minDisplacement:Number = _getSmallestIntervalAsSemitones(_stepMotionWeights);
				var maxDisplacement:Number = _getGreatestIntervalAsSemitones(_skipMotionWeights);
				var skipMotionThreshold:Number = Math.floor((maxDisplacement - minDisplacement) *
					0.5);
				var signedDisplacement:Number = 0;
				var haveProperAnalysis:Boolean = false;
				while (analisysQueue.length > 0) {
					var current:MusicEntry = analisysQueue.shift();
					var previous:MusicEntry = (analisysQueue.length > 0) ? (analisysQueue[0] as
						MusicEntry) : null;
					if (current != null && previous != null) {
						haveProperAnalysis = true;
						var currentPitch:int = current.pitch;
						var previousPitch:int = previous.pitch;
						var delta:int = currentPitch - previousPitch;
						signedDisplacement += delta;
					}
				}
				// Use step motion if there aren't enough pitches to analyse
				if (!haveProperAnalysis) {
					return _stepMotionWeights;
				}
				if (Math.abs(signedDisplacement) >= skipMotionThreshold) {
					return _stepMotionWeights;
				}
			}
			return _skipMotionWeights;
		}

		private function _getNumSemitones(interval:String):int {
			var semitones:int = -1;
			switch (interval) {
				case PERFECT_PRIME:
					semitones = 0;
					break;
				case MINOR_SECOND:
					semitones = 1;
					break;
				case MAJOR_SECOND:
					semitones = 2;
					break;
				case MINOR_THIRD:
					semitones = 3;
					break;
				case MAJOR_THIRD:
					semitones = 4;
					break;
				case PERFECT_FOURTH:
					semitones = 5;
					break;
				case AUGMENTED_FORTH:
					semitones = 6;
					break;
				case PERFECT_FIFTH:
					semitones = 7;
					break;
				case MINOR_SIXTH:
					semitones = 8;
					break;
				case MAJOR_SIXTH:
					semitones = 9;
					break;
				case MINOR_SEVENTH:
					semitones = 10;
					break;
				case MAJOR_SEVENTH:
					semitones = 11;
					break;
			}
			return semitones;
		}

		private function _getNumericValue(text:String):Number {
			var isNegative:Boolean = (text.charAt(0) == '-');
			var numMatch:Array = text.match(/\d{1,}/);
			if (numMatch != null) {
				var numVal:Number = parseInt(numMatch[0] as String);
				if (!isNaN(numVal)) {
					if (isNegative) {
						numVal *= -1;
					}
					return numVal;
				}
			}
			return 0;
		}

		private function _getSkipIntervalsTable():Array {
			return createCombinations([MINOR_THIRD, MAJOR_THIRD, PERFECT_FOURTH,
				AUGMENTED_FORTH, PERFECT_FIFTH, MINOR_SIXTH, MAJOR_SIXTH, MINOR_SEVENTH,
				MAJOR_SEVENTH], [SUBTRACT_FIFTY, SUBTRACT_TEN, SUBTRACT_FIVE, SUBTRACT_ONE,
				ADD_ONE, ADD_FIVE, ADD_TEN, ADD_FIFTY]);
		}

		private function _getSmallestIntervalAsSemitones(weightsTable:Object):int {
			var minSemitones:int = -1;
			for (var intervalName:String in weightsTable) {
				var numSemitones:int = _getNumSemitones(intervalName);
				if (minSemitones == -1 || numSemitones < minSemitones) {
					minSemitones = numSemitones;
				}
			}
			return minSemitones;
		}

		private function _getStepIntervalsTable():Array {
			return createCombinations([PERFECT_PRIME, MINOR_SECOND, MAJOR_SECOND],
				[SUBTRACT_FIFTY, SUBTRACT_TEN, SUBTRACT_FIVE, SUBTRACT_ONE, ADD_ONE,
				ADD_FIVE, ADD_TEN, ADD_FIFTY]);
		}

		private function _isPitched(note:MusicEntry):Boolean {
			return (note.pitch > 0);
		}

		private function _makeInitialEntry():MusicEntry {
			var picker:WeightedRandomPicker = new WeightedRandomPicker;
			var basePitch:int = _getBasePitch();
			var start:int = (_mainDirection == DIRECTION_UP) ? (basePitch - 6) :
				(basePitch + 6);
			var end:int = (start + 12);
			for (var i:int = start; i < end; i++) {
				var weight:Number = (i == basePitch) ? BASE_PITCH_WEIGHT : (i ==
					start) ? START_PITCH_WEIGHT : (i == end) ? END_PITCH_WEIGHT :
					COMMON_PITCH_WEIGHT;
				var note:MusicEntry = new MusicEntry(i, Fraction.fromString(_durationPicker.
					pick()));
				picker.setOption(note.toString(), weight);
			}
			return MusicEntry.fromString(picker.pick());
		}

		private function _makeSubsequentEntry():MusicEntry {
			var entryType:String = _entryPicker.pick();
			var noteSrc:String = _notePicker.pick();
			var note:MusicEntry = MusicEntry.fromString(noteSrc);
			var durationSrc:String = _durationPicker.pick();
			note.duration = Fraction.fromString(durationSrc);
			var isNote:Boolean = (entryType == NOTE_TYPE);
			if (!isNote) {
				note.pitch = 0;
			}
			return note;
		}

		private function _noteFits(note:MusicEntry):Boolean {
			var durationRemainder:Fraction = _totalDuration.subtract(_durationSoFar) as Fraction;
			var duration:Fraction = note.duration;
			var isLessThan:Boolean = duration.lessThan(durationRemainder);
			var isEqual:Boolean = duration.equals(durationRemainder);
			return (isLessThan || isEqual);
		}

		private function _rebuildDirectionPicker():WeightedRandomPicker {
			if (_mainDirection == null) {
				_mainDirection = (_initialDirectionIsUp ? DIRECTION_UP : DIRECTION_DOWN);
			}
			if (_alternateDirection == null) {
				_alternateDirection = ((_mainDirection == DIRECTION_UP) ? DIRECTION_DOWN :
					DIRECTION_UP);
			}
			var mainDirectionWeight:Number = _initialDirectionWeight;
			var directionAdjustment:Number = _computeDirectionAdjustment();
			mainDirectionWeight += directionAdjustment;
			mainDirectionWeight = Math.abs(mainDirectionWeight);
			var alternateDirectionWeight:Number = (1 - mainDirectionWeight);
			var picker:WeightedRandomPicker = new WeightedRandomPicker();
			picker.infiniteOptions = true;
			var percentComplete:Number = _computeCompletedPercent();
			if (percentComplete < _climaxPoint) {
				picker.setOption(_mainDirection, mainDirectionWeight);
				picker.setOption(_alternateDirection, alternateDirectionWeight);
			} else {
				picker.setOption(_mainDirection, alternateDirectionWeight);
				picker.setOption(_alternateDirection, mainDirectionWeight);
			}
			return picker;
		}

		private function _rebuildDurationPicker():WeightedRandomPicker {
			var picker:WeightedRandomPicker = new WeightedRandomPicker();
			picker.infiniteOptions = true;
			var durationsWeights:Object = _buildWeightsTable(durations);
			for (var durationKey:String in durationsWeights) {
				var durationWeight:Number = durationsWeights[durationKey];
				picker.setOption(durationKey, durationWeight);
			}
			return picker;
		}

		private function _rebuildEntryPicker():WeightedRandomPicker {
			var picker:WeightedRandomPicker = new WeightedRandomPicker();
			picker.infiniteOptions = true;
			var notesWeight:Number = _useRests? _notesToRestsRatio : 1;
			var restsWeight:Number = _useRests? (1 - notesWeight) : 0;
			picker.setOption(NOTE_TYPE, notesWeight);
			picker.setOption(REST_TYPE, restsWeight);
			return picker;
		}

		private function _rebuildIntervalPicker():WeightedRandomPicker {
			var picker:WeightedRandomPicker = new WeightedRandomPicker();
			picker.infiniteOptions = true;
			var intervalWeights:Object = _getIntervalWeights();
			for (var intervalName:String in intervalWeights) {
				var intervalWeight:Number = intervalWeights[intervalName];
				picker.setOption(intervalName, intervalWeight);
			}
			return picker;
		}

		private function _rebuildNotePicker():WeightedRandomPicker {
			var directionPicker:WeightedRandomPicker = _rebuildDirectionPicker();
			var intervalPicker:WeightedRandomPicker = _rebuildIntervalPicker();
			var directionKey:String = directionPicker.pick();
			var direction:int = ((directionKey == DIRECTION_UP) ? 1 : -1);
			var interval:int = _getNumSemitones(intervalPicker.pick());
			var lastNote:MusicEntry = null;
			var lastPitch:int = _getBasePitch();
			var queueCopy:Array = _queue.concat();
			while (lastNote == null && queueCopy.length > 0) {
				var testNote:MusicEntry = (queueCopy.pop() as MusicEntry);
				if (_isPitched(testNote)) {
					lastNote = testNote;
					break;
				}
			}
			if (lastNote != null) {
				lastPitch = lastNote.pitch;
			}
			var rightPitch:int = Math.max(0, Math.min(127, lastPitch + (interval *
				direction)));
			var rightNote:MusicEntry = new MusicEntry(rightPitch);
			// We ensure there is a minimum chance for a `wrong` note to be picked — e.g., picking 
			// a downward note when user insisted that the melody should go up would be a `wrong` note.
			// This could save the generated melody from becoming a scale, in some situations.
			var wrongPitch:int = Math.max(0, Math.min(127, lastPitch + (interval *
				direction * -1)));
			var wrongNote:MusicEntry = new MusicEntry(wrongPitch);
			var picker:WeightedRandomPicker = new WeightedRandomPicker;
			picker.setOption(rightNote.toString(), RIGHT_NOTE_WEIGHT);
			picker.setOption(wrongNote.toString(), WRONG_NOTE_WEIGHT);
			return picker;
		}

		private function _split(val:String):Array {
			var segments:Array = val.split('\n');
			for (var i:int = 0; i < segments.length; i++) {
				segments[i] = Strings.trim(segments[i] as String);
			}
			return segments;
		}
		
		private function _clearCache () : void {
			_durationPicker = null;
			_entryPicker = null;
			_alternateDirection = null;
			_durationWeightsTable = null;
			_mainDirection = null;
		}
	}
}

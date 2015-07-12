using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Position as Position;
using Toybox.System as Sys;
using Toybox.Timer as Timer;
using Toybox.Math as Math;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Gregorian;
using Toybox.ActivityRecording as Record;
using CommuteHistory as CommuteHistory;
using Toybox.Position as Position;
using Toybox.Activity as Activity;
using CommuteTrackerUtil as CommuteTrackerUtil;


module CommuteActivity {

	hidden const UPDATE_PERIOD_SEC = 1; // [seconds]
	hidden const MIN_MOVING_SPEED = 4.5; // [m/s] ~ 10mph
	hidden var activityController;

	function getCommuteActivityController() {
		if( activityController == null ) {
			activityController = new CommuteActivityController();
		}
		return activityController;
	}


	hidden class CommuteActivityController {
	
		hidden var activityView = null;
		hidden var activityModel = null;
		hidden var hasActiveActivity = false;
		hidden var summaryView = null;
		
		function getActivityView() {
			activityModel = new CommuteActivityModel();
			activityView = new CommuteActivityView(activityModel);
			hasActiveActivity = true;
			return activityView;
		}
		
		function getActivityDelegate() {
			return new CommuteActivityDelegate();
		}
		
		
		function saveActivity() {
			if( hasActiveActivity ) {
				// Remove the activity view
				Ui.popView(Ui.SLIDE_IMMEDIATE);
	            Ui.popView(Ui.SLIDE_IMMEDIATE);
			
				activityModel.pauseActivity(); // Stop the timer and position updates
	    		CommuteHistory.saveCommute(activityModel);
            
	            // Show the activity summary
	            summaryView = new CommuteSummaryView(activityModel);
		        Ui.pushView(summaryView, new CommuteSummaryDelegate(summaryView), Ui.SLIDE_LEFT);
	        }
		}
		
		function discardActivity() {
			if( hasActiveActivity ) {
				// Remove the activity view without saving any data
				Ui.popView(Ui.SLIDE_IMMEDIATE);
				activityModel.pauseActivity(); // Stop the timer and position updates
			}
		
			activityModel = null;
			activityView = null;
			hasActiveActivity = false;
		}
		
		function getSummaryView() {
			return summaryView;
		}
		
	}
	
	
	hidden class CommuteActivityModel {
	
		hidden var totalDistance = null; // in meters
		hidden var timeMoving = null; // in seconds
		hidden var timeStopped = null; // in seconds
		hidden var commuteStartTime = null; // Moment object
		hidden var numStops = null; // Integer
		hidden var maxSpeed = null; // In meters per second
		hidden var currentSpeed = null; // In meters per second
		
		hidden var timer = null; // Timer object
		hidden var isMoving = false;
		hidden var isValidGPS = false;

		
		
		function initialize() {
			totalDistance = 0.0;
			timeMoving = 0;
			timeStopped = 0;
			commuteStartTime = Time.now();
			numStops = 0;
			maxSpeed = 0;
			currentSpeed = 0;
			timer = new Timer.Timer();
		}
		
		function pauseActivity() {
			timer.stop();
	    	Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
		}
		
		function resumeActivity() {
			timer.start(method(:updateActivity), UPDATE_PERIOD_SEC * 1000, true);
	    	Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
		}
		
		///! This function runs once every 1 second. It updates the stopped and moving times
		function updateActivity() {
			if( isValidGPS ) {
				
				// Update the total distance travelled by integrating the speed over time
				totalDistance += currentSpeed * UPDATE_PERIOD_SEC;
				
				if( isMoving ) {
					timeMoving += UPDATE_PERIOD_SEC; 
				} else {
					timeStopped += UPDATE_PERIOD_SEC;
				}
			}
			
			Ui.requestUpdate(); // Update the timer displayed on the screen
		}
		
		function onPosition(info) {
			// Check that we have a good enough GPS fix
			if( info.accuracy != Position.QUALITY_NOT_AVAILABLE ) {
				isValidGPS = true;
				
				currentSpeed = info.speed;
				
				if( currentSpeed > MIN_MOVING_SPEED ) {
					isMoving = true;
					
					// Check if we have acheived a new maximum speed
					if( info.speed > maxSpeed ) {
						maxSpeed = info.speed;
					}
					
				} else {
					// Check if we have just come to a stop
					if( isMoving ) {
						numStops++;
					}
					isMoving = false;
				}
				
			} else {
				// Don't update the state because the GPS fix is not good enough
				isValidGPS = false;
			}
		}
		
		function isMoving() {
			return isMoving;
		}
		
		function hasGPSFix() {
			return isValidGPS;
		}
		
		function getTotalDistance() {
			return totalDistance;
		}
		
		function getNumStops() {
			return numStops;
		}
		
		function getCommuteEfficiency() {
			var efficiency = 0;
			var totalTime = timeMoving + timeStopped;
			// Check for divide by zero
			if( 0 != totalTime ) {
				efficiency = (timeMoving * 100) / totalTime;
			}
			return efficiency;
		}
		
		function getCommuteStartTime() {
			return commuteStartTime;
		}
		
		function getTimeMoving() {
			return timeMoving;
		}
		
		function getTimeStopped() {
			return timeStopped;
		}
		
		function getTotalCommuteTime() {
			return timeMoving + timeStopped;
		}
		
		function getMaxSpeed() {
			return maxSpeed;
		}
	}


	hidden class CommuteActivityView extends Ui.View {
	
		hidden var commuteModel = null;
	
		function initialize(model) {
			commuteModel = model;
		}
	
	    //! Load resources
	    function onLayout(dc) {
	    }
	
	    //! Restore the state of the app and prepare the view to be shown
	    function onShow() {
	    	commuteModel.resumeActivity();
	    }
	
	    //! Update the view
	    function onUpdate(dc) {
		    dc.setColor( Gfx.COLOR_WHITE, Gfx.COLOR_WHITE );
	        dc.clear();
	        dc.setColor( Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT );
	    	if( commuteModel.hasGPSFix() ) {
		    	// Update the running time of this activity
				var timeMoving = commuteModel.getTimeMoving();
				var timeStopped = commuteModel.getTimeStopped();
		    	var timeMovingString = CommuteTrackerUtil.formatDuration(timeMoving);
		    	var timeStoppedString = CommuteTrackerUtil.formatDuration(timeStopped);
		    	var totalTimeString = CommuteTrackerUtil.formatDuration(timeMoving + timeStopped);
				

				// Display the moving time
				dc.drawText(( dc.getWidth()/4), 5, Gfx.FONT_SMALL, "Move Time", Gfx.TEXT_JUSTIFY_CENTER );
		        dc.drawText(( dc.getWidth()/4), (dc.getHeight() / 6), Gfx.FONT_NUMBER_MEDIUM, timeMovingString, Gfx.TEXT_JUSTIFY_CENTER );
		        
		        // Display the time stopped
		        dc.drawText(( 3*dc.getWidth()/4), 5, Gfx.FONT_SMALL, "Stop Time", Gfx.TEXT_JUSTIFY_CENTER );
		        dc.drawText(( 3*dc.getWidth()/4), (dc.getHeight() / 6), Gfx.FONT_NUMBER_MEDIUM, timeStoppedString, Gfx.TEXT_JUSTIFY_CENTER );
		        
		        // Display the total time
		        dc.drawText( (dc.getWidth()/2), (dc.getHeight()/2) + 5, Gfx.FONT_SMALL, "Total Time", Gfx.TEXT_JUSTIFY_CENTER);
		        dc.drawText(( dc.getWidth()/2), (2*dc.getHeight() / 3), Gfx.FONT_NUMBER_MEDIUM, totalTimeString, Gfx.TEXT_JUSTIFY_CENTER );
		        
		        
		        
		        // Draw the dividing bars
				dc.setColor( Gfx.COLOR_DK_BLUE, Gfx.COLOR_TRANSPARENT );
				dc.fillRectangle((dc.getWidth()/2), 0, 5, dc.getHeight()/2); // Vertical bar
				dc.fillRectangle(0,(dc.getHeight()/2), dc.getWidth(), 5); // horizontal bar

		        
		        // Draw a bar along the bottom to represent commute efficiency
				var efficiency = commuteModel.getCommuteEfficiency();
		        var barColor = Gfx.COLOR_WHITE;
		        var barWidth = dc.getWidth() * efficiency / 100.0;
		        if( efficiency < 25 ) {
		        	barColor = Gfx.COLOR_RED;
		        } else if( efficiency < 50 ) {
		        	barColor = Gfx.COLOR_ORANGE;
		        } else if( efficiency < 75 ) {
		        	barColor = Gfx.COLOR_YELLOW;
		        } else {
		        	barColor = Gfx.COLOR_GREEN;
		        }
		        
		        dc.setColor(barColor, Gfx.COLOR_TRANSPARENT);
		        dc.fillRectangle(0, dc.getHeight() - 10, barWidth, 10);
		        
		        
	        } else {
	        	dc.drawText((dc.getWidth()/2), (dc.getHeight()/2), Gfx.FONT_LARGE, "Wait for GPS", Gfx.TEXT_JUSTIFY_CENTER);
	        }
	    }
	
	    //! Called when this View is removed from the screen. 
	    function onHide() {
	    	commuteModel.pauseActivity();
	    }
		
	}
	
	
	hidden class CommuteActivityDelegate extends Ui.InputDelegate {
	
		function onKey(keyEvent) {
			var key = keyEvent.getKey();
			if( key == Ui.KEY_ENTER || key == Ui.KEY_ESC ) {
				// The user may want to exit the activity.
				Ui.pushView(new Rez.Menus.CommuteActivityMenu(), new CommuteActivityMenuDelegate(), Ui.SLIDE_IMMEDIATE);
			} 
		}
	
	}
	
	
	
	hidden class CommuteActivityMenuDelegate extends Ui.MenuInputDelegate {

	    function onMenuItem(item) {
	        if (item == :resume) {
	        	// Do nothing, return to the activity
	        } else if (item == :save) {
	            getCommuteActivityController().saveActivity();
	        } else if ( item == :discard ) {
				getCommuteActivityController().discardActivity();
	        }
	    }
	}
	
	
	
	
}

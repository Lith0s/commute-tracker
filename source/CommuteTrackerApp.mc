using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.System as Sys;

class CommuteTrackerApp extends App.AppBase {

    //! onStart() is called on application start up
    function onStart() {
    }

    //! onStop() is called when your application is exiting
    function onStop() {
    }

    //! Return the initial view of your application here
    function getInitialView() {
        return [ new MainView(), new CommuteTrackerDelegate() ];
    }

}

class CommuteTrackerDelegate extends Ui.BehaviorDelegate {

    function onMenu() {
    	Sys.println("Opening Menu");
        Ui.pushView(new Rez.Menus.MainMenu(), new MainMenuDelegate(), Ui.SLIDE_UP);
        return true;
    }

}
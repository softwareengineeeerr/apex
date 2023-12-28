public class RecursionBlocker {
	private static Boolean runStatus = true;
    
    public static Boolean isFirstRun() {
        return runStatus;
    }
    
    public static void setFirstRunAsFalse() {
        runStatus = false;
    }
}
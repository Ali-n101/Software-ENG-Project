package Services;

/** FR-11: thrown when the chosen time was booked by someone else before confirmation. */
public class SlotUnavailableException extends Exception {
    public SlotUnavailableException(String message) {
        super(message);
    }
}

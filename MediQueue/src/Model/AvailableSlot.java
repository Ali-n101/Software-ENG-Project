package Model;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

public class AvailableSlot {
    private int slotId;
    private LocalDateTime startTime;
    private LocalDateTime endTime;

    private static final DateTimeFormatter FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd  hh:mm a");

    public AvailableSlot(int slotId, LocalDateTime startTime, LocalDateTime endTime) {
        this.slotId = slotId;
        this.startTime = startTime;
        this.endTime = endTime;
    }

    public int getSlotId() { return slotId; }
    public LocalDateTime getStartTime() { return startTime; }
    public LocalDateTime getEndTime() { return endTime; }

    @Override
    public String toString() {
        return startTime.format(FORMATTER);
    }
}
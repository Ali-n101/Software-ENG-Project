package Model;

import java.time.LocalDateTime;

public class BookingConfirmation {
    private String referenceNo;
    private String patientName;
    private String clinicName;
    private String clinicLocation;
    private LocalDateTime startTime;

    public BookingConfirmation(String referenceNo, String patientName, String clinicName, String clinicLocation, LocalDateTime startTime) {
        this.referenceNo = referenceNo;
        this.patientName = patientName;
        this.clinicName = clinicName;
        this.clinicLocation = clinicLocation;
        this.startTime = startTime;
    }

    public String getReferenceNo() { return referenceNo; }
    public String getPatientName() { return patientName; }
    public String getClinicName() { return clinicName; }
    public String getClinicLocation() { return clinicLocation; }
    public LocalDateTime getStartTime() { return startTime; }
}
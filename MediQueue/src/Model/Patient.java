package Model;

public class Patient {
    private int patientId;
    private String nationalId;
    private String fullName;

    public Patient(int patientId, String nationalId, String fullName) {
        this.patientId = patientId;
        this.nationalId = nationalId;
        this.fullName = fullName;
    }

    public int getPatientId() { return patientId; }
    public String getNationalId() { return nationalId; }
    public String getFullName() { return fullName; }
}
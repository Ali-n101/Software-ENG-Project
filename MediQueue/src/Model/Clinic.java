package Model;

public class Clinic {
    private short clinicId;
    private String name;
    private String location;

    public Clinic(short clinicId, String name, String location) {
        this.clinicId = clinicId;
        this.name = name;
        this.location = location;
    }

    public short getClinicId() { return clinicId; }
    public String getName() { return name; }
    public String getLocation() { return location; }

    @Override
    public String toString() {
        return name + " (" + location + ")";
    }
}
package Dao;

import Model.*;
import Util.DatabaseConnection;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

public class BookingDao {

    // FR-01: Identify patient
    public Optional<Patient> findPatientByNationalId(String nationalId) throws SQLException {
        String sql = "SELECT patient_id, national_id, full_name FROM patient WHERE national_id = ?";
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, nationalId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(new Patient(
                            rs.getInt("patient_id"),
                            rs.getString("national_id"),
                            rs.getString("full_name")
                    ));
                }
            }
        }
        return Optional.empty();
    }

    // FR-03: List active clinics
    public List<Clinic> getActiveClinics() throws SQLException {
        List<Clinic> clinics = new ArrayList<>();
        String sql = "SELECT clinic_id, name, location FROM clinic WHERE is_active = TRUE ORDER BY name";
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                clinics.add(new Clinic(
                        rs.getShort("clinic_id"),
                        rs.getString("name"),
                        rs.getString("location")
                ));
            }
        }
        return clinics;
    }

    // FR-05: Available slots for a clinic
    public List<AvailableSlot> getAvailableSlots(short clinicId) throws SQLException {
        List<AvailableSlot> slots = new ArrayList<>();
        String sql = "SELECT slot_id, start_time, end_time FROM available_slot WHERE clinic_id = ? ORDER BY start_time";
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setShort(1, clinicId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    slots.add(new AvailableSlot(
                            rs.getInt("slot_id"),
                            rs.getTimestamp("start_time").toLocalDateTime(),
                            rs.getTimestamp("end_time").toLocalDateTime()
                    ));
                }
            }
        }
        return slots;
    }

    // FR-07, FR-08, FR-11: Book appointment with 1062 catch
    public int bookAppointment(int slotId, int patientId) throws SQLException, IllegalStateException {
        String sql = "INSERT INTO appointment (slot_id, patient_id) VALUES (?, ?)";
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setInt(1, slotId);
            ps.setInt(2, patientId);
            ps.executeUpdate();

            try (ResultSet rs = ps.getGeneratedKeys()) {
                if (rs.next()) {
                    return rs.getInt(1);
                }
            }
        } catch (SQLException e) {
            if (e.getErrorCode() == 1062) {
                throw new IllegalStateException("SLOT_ALREADY_BOOKED");
            }
            throw e;
        }
        throw new SQLException("Failed to retrieve booking ID.");
    }

   
   // FR-09: Get confirmation from booking_confirmation view
    public Optional<BookingConfirmation> getConfirmation(int appointmentId) throws SQLException {
        String sql = "SELECT * FROM booking_confirmation WHERE appointment_id = ?";
        try (Connection conn = DatabaseConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, appointmentId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    ResultSetMetaData meta = rs.getMetaData();
                    int columnCount = meta.getColumnCount();

                    String refNo = "N/A";
                    String patientName = "N/A";
                    String clinicName = "N/A";
                    String clinicLocation = "N/A";
                    java.time.LocalDateTime startTime = java.time.LocalDateTime.now();

                    for (int i = 1; i <= columnCount; i++) {
                        String col = meta.getColumnLabel(i).toLowerCase();
                        if (col.contains("ref") || col.contains("code") || col.equals("reference_no")) {
                            refNo = rs.getString(i);
                        } else if (col.contains("patient") || col.contains("full_name") || col.equals("name")) {
                            if (patientName.equals("N/A")) patientName = rs.getString(i);
                        } else if (col.contains("clinic")) {
                            clinicName = rs.getString(i);
                        } else if (col.contains("loc")) {
                            clinicLocation = rs.getString(i);
                        } else if (col.equals("start_time") || col.equals("starttime")) {
                            Timestamp ts = rs.getTimestamp(i);
                            if (ts != null) startTime = ts.toLocalDateTime();
                        }
                    }

                    if (refNo.equals("N/A") || refNo.isEmpty()) {
                        refNo = String.format("MQ-%06d", appointmentId);
                    }

                    return Optional.of(new BookingConfirmation(
                            refNo,
                            patientName,
                            clinicName,
                            clinicLocation,
                            startTime
                    ));
                }
            }
        }
        return Optional.empty();
    }
}

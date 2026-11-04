package Services;

import Dao.BookingDao;
import Model.*;

import java.sql.SQLException;
import java.util.List;

public class BookingService {
    private final BookingDao dao = new BookingDao();

    // FR-01, FR-02: فحص الهوية والتأكد من أنها 10 أرقام تبدأ بـ 1 أو 2
    public Patient validateAndGetPatient(String nationalId) throws Exception {
        if (nationalId == null || !nationalId.matches("^[12]\\d{9}$")) {
            throw new IllegalArgumentException("رقم الهوية غير صحيح، يجب أن يتكون من 10 أرقام ويبدأ بـ 1 أو 2.");
        }
        return dao.findPatientByNationalId(nationalId)
                .orElseThrow(() -> new IllegalArgumentException("لم يتم العثور على مريض مسجل بهذا الرقم."));
    }

    public List<Clinic> getClinics() throws SQLException {
        return dao.getActiveClinics();
    }

    public List<AvailableSlot> getSlotsForClinic(short clinicId) throws SQLException {
        return dao.getAvailableSlots(clinicId);
    }

    public BookingConfirmation confirmBooking(int slotId, int patientId) throws Exception {
        try {
            int appointmentId = dao.bookAppointment(slotId, patientId);
            return dao.getConfirmation(appointmentId)
                    .orElseThrow(() -> new Exception("تعذر استرجاع تفاصيل الحجز."));
        } catch (IllegalStateException e) {
            // FR-11
            throw new SlotUnavailableException("هذا الوقت لم يعد متاحاً، الرجاء اختيار وقت آخر.");
        }
    }
}
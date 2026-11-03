import Model.*;
import Services.BookingService;
import Util.DatabaseConnection;

import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Scanner;

public class Main {
    private static final DateTimeFormatter FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd  hh:mm a");

    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        System.out.println("==================================================");
        System.out.println("          Database Login Setup");
        System.out.println("==================================================");

        // طلب بيانات قاعدة البيانات في البداية
        System.out.print("Enter MySQL Username (e.g. root): ");
        String dbUser = scanner.nextLine();

        System.out.print("Enter MySQL Password: ");
        String dbPass = scanner.nextLine();

        DatabaseConnection.setCredentials(dbUser, dbPass);

        // فحص الاتصال قبل البدء
        try {
            DatabaseConnection.getConnection().close();
            System.out.println("Connected to MySQL successfully!\n");
        } catch (Exception e) {
            System.out.println("[Connection Error]: " + e.getMessage());
            System.out.println("Failed to connect. Exiting...");
            return;
        }

        // بدء تشغيل مسار الحجز
        BookingService service = new BookingService();

        System.out.println("==================================================");
        System.out.println("     MediQueue Reception Kiosk - Testing");
        System.out.println("==================================================");

        try {
            System.out.print("Enter National ID (10 digits): ");
            String idInput = scanner.nextLine();
            Patient patient = service.validateAndGetPatient(idInput);
            System.out.println("Verified successfully! Welcome, " + patient.getFullName());

            System.out.println("\nAvailable Clinics:");
            List<Clinic> clinics = service.getClinics();
            for (int i = 0; i < clinics.size(); i++) {
                System.out.println((i + 1) + ". " + clinics.get(i).getName());
            }

            System.out.print("Select a clinic number: ");
            int clinicChoice = Integer.parseInt(scanner.nextLine());
            Clinic selectedClinic = clinics.get(clinicChoice - 1);

            List<AvailableSlot> slots = service.getSlotsForClinic(selectedClinic.getClinicId());
            if (slots.isEmpty()) {
                System.out.println("[Notice FR-10]: No appointment times are available for this clinic.");
                return;
            }

            System.out.println("\nAvailable Slots for " + selectedClinic.getName() + ":");
            for (int i = 0; i < slots.size(); i++) {
                System.out.println((i + 1) + ". " + slots.get(i).getStartTime().format(FORMATTER));
            }

            System.out.print("Select a slot number to book: ");
            int slotChoice = Integer.parseInt(scanner.nextLine());
            AvailableSlot selectedSlot = slots.get(slotChoice - 1);

            BookingConfirmation confirmation = service.confirmBooking(selectedSlot.getSlotId(), patient.getPatientId());
            System.out.println("\n==================================================");
            System.out.println("         BOOKING CONFIRMED SUCCESSFULLY (FR-09)");
            System.out.println("==================================================");
            System.out.println("Reference No : " + confirmation.getReferenceNo());
            System.out.println("Patient Name : " + confirmation.getPatientName());
            System.out.println("Clinic       : " + confirmation.getClinicName());
            System.out.println("Location     : " + confirmation.getClinicLocation());
            System.out.println("Date & Time  : " + confirmation.getStartTime().format(FORMATTER));
            System.out.println("==================================================");

        } catch (Exception e) {
            System.out.println("\n[Error]: " + e.getMessage());
        }
    }
}

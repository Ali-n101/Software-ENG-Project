package UI;

import Model.BookingConfirmation;
import Model.Clinic;
import Model.Patient;
import Services.BookingService;
import javafx.application.Application;
import javafx.scene.Parent;
import javafx.scene.Scene;
import javafx.scene.input.KeyCode;
import javafx.scene.input.KeyEvent;
import javafx.scene.layout.StackPane;
import javafx.stage.Stage;

import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.format.DateTimeFormatter;
import java.util.Locale;

/**
 * JavaFX entry point and screen navigator for the MediQueue kiosk.
 * Flow: Setup -> Identify (FR-01/02) -> Clinic (FR-03/04) -> Time (FR-05..08, 10, 11) -> Confirmation (FR-09)
 */
public class KioskApp extends Application {
    static final DateTimeFormatter TIME = DateTimeFormatter.ofPattern("hh:mm a", Locale.ENGLISH);
    static final DateTimeFormatter DAY = DateTimeFormatter.ofPattern("EEE, d MMM", Locale.ENGLISH);
    static final DateTimeFormatter FULL = DateTimeFormatter.ofPattern("EEEE d MMMM yyyy, hh:mm a", Locale.ENGLISH);

    final BookingService service = new BookingService();
    Patient patient;
    Clinic clinic;

    private Scene scene;
    private Runnable cleanup;

    @Override
    public void start(Stage stage) {
        scene = new Scene(new StackPane(), 1200, 780);
        String css = findStylesheet();
        if (css != null) {
            scene.getStylesheets().add(css);
        }
        // F11 toggles full screen, like a real kiosk.
        scene.addEventFilter(KeyEvent.KEY_PRESSED, e -> {
            if (e.getCode() == KeyCode.F11) {
                stage.setFullScreen(!stage.isFullScreen());
            }
        });

        stage.setTitle("MediQueue - Self-Service Kiosk");
        stage.setMinWidth(960);
        stage.setMinHeight(680);
        stage.setScene(scene);
        show(new DbSetupView(this).build(), null);
        stage.show();
    }

    /** Replaces the current screen; runs the previous screen's cleanup (e.g. timers). */
    void show(Parent view, Runnable onLeave) {
        if (cleanup != null) {
            cleanup.run();
        }
        cleanup = onLeave;
        scene.setRoot(view);
    }

    void startOver() {
        patient = null;
        clinic = null;
        show(new IdentifyView(this).build(), null);
    }

    void goClinics() {
        clinic = null;
        show(new ClinicView(this).build(), null);
    }

    void goSlots() {
        show(new SlotView(this).build(), null);
    }

    void goConfirmation(BookingConfirmation confirmation) {
        ConfirmationView view = new ConfirmationView(this, confirmation);
        show(view.build(), view::stop);
    }

    private String findStylesheet() {
        URL url = KioskApp.class.getResource("kiosk.css");
        if (url != null) {
            return url.toExternalForm();
        }
        for (String candidate : new String[] {"src/UI/kiosk.css", "MediQueue/src/UI/kiosk.css"}) {
            Path path = Paths.get(candidate);
            if (Files.exists(path)) {
                return path.toUri().toString();
            }
        }
        System.err.println("Warning: kiosk.css not found; using default styling.");
        return null;
    }
}

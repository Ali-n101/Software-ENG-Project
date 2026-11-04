package UI;

import Model.BookingConfirmation;
import javafx.animation.KeyFrame;
import javafx.animation.Timeline;
import javafx.geometry.Pos;
import javafx.scene.Parent;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.control.Separator;
import javafx.scene.layout.GridPane;
import javafx.scene.layout.VBox;
import javafx.scene.text.TextAlignment;
import javafx.util.Duration;

/** Step 4 - FR-09: booking confirmation, then automatic return to the start screen. */
class ConfirmationView {
    private static final int RETURN_SECONDS = 45;

    private final KioskApp app;
    private final BookingConfirmation confirmation;
    private Timeline timer;
    private int remaining = RETURN_SECONDS;

    ConfirmationView(KioskApp app, BookingConfirmation confirmation) {
        this.app = app;
        this.confirmation = confirmation;
    }

    Parent build() {
        Label check = new Label("✓");
        check.getStyleClass().add("check-circle");

        Label refCaption = new Label("Your reference number  ·  رقم الحجز");
        refCaption.getStyleClass().add("muted");
        Label ref = new Label(confirmation.getReferenceNo());
        ref.getStyleClass().add("ref-label");
        VBox refBox = new VBox(4, refCaption, ref);
        refBox.setAlignment(Pos.CENTER);

        GridPane details = new GridPane();
        details.setHgap(28);
        details.setVgap(12);
        details.setAlignment(Pos.CENTER);
        addDetail(details, 0, "Patient", confirmation.getPatientName());
        addDetail(details, 1, "Clinic", confirmation.getClinicName());
        addDetail(details, 2, "Location", confirmation.getClinicLocation());
        addDetail(details, 3, "Date & time", confirmation.getStartTime().format(KioskApp.FULL));

        Label instruction = new Label("Please go to " + confirmation.getClinicLocation()
                + " and arrive 15 minutes before your appointment.");
        instruction.getStyleClass().add("muted");
        instruction.setWrapText(true);
        instruction.setTextAlignment(TextAlignment.CENTER);

        VBox panel = new VBox(20, check, refBox, new Separator(), details, instruction);
        panel.getStyleClass().add("panel");
        panel.setAlignment(Pos.CENTER);
        panel.setMaxWidth(720);

        VBox body = new VBox(panel);
        body.setAlignment(Pos.TOP_CENTER);

        Label countdown = new Label();
        countdown.getStyleClass().add("muted");
        updateCountdown(countdown);

        Button done = Ui.primary("Done");
        done.setDefaultButton(true);
        done.setOnAction(e -> app.startOver());

        timer = new Timeline(new KeyFrame(Duration.seconds(1), e -> {
            remaining--;
            updateCountdown(countdown);
            if (remaining <= 0) {
                app.startOver();
            }
        }));
        timer.setCycleCount(RETURN_SECONDS);
        timer.play();

        return Ui.page(3, "Booking confirmed", "تم تأكيد الحجز بنجاح", body, countdown, Ui.spacer(), done);
    }

    void stop() {
        if (timer != null) {
            timer.stop();
        }
    }

    private void updateCountdown(Label label) {
        label.setText("Returning to the start screen in " + remaining + " s");
    }

    private static void addDetail(GridPane grid, int row, String key, String value) {
        Label k = new Label(key);
        k.getStyleClass().add("detail-key");
        Label v = new Label(value);
        v.getStyleClass().add("detail-value");
        v.setWrapText(true);
        grid.addRow(row, k, v);
    }
}

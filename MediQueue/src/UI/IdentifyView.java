package UI;

import javafx.application.Platform;
import javafx.geometry.Pos;
import javafx.scene.Parent;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.control.TextField;
import javafx.scene.control.TextFormatter;
import javafx.scene.layout.GridPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.Priority;
import javafx.scene.layout.VBox;

/** Step 1 - FR-01, FR-02, NFR-04: patient enters and validates their National ID. */
class IdentifyView {
    private static final String CONTINUE = "Continue";
    private final KioskApp app;
    private TextField field;
    private Label error;
    private Button next;

    IdentifyView(KioskApp app) {
        this.app = app;
    }

    Parent build() {
        field = new TextField();
        field.setPromptText("10-digit National ID");
        field.getStyleClass().add("id-field");
        field.setMaxWidth(460);
        // Digits only, maximum 10.
        field.setTextFormatter(new TextFormatter<String>(change ->
                change.getControlNewText().matches("\\d{0,10}") ? change : null));
        field.textProperty().addListener((obs, oldText, newText) -> Ui.hide(error));

        error = Ui.errorBanner();
        error.setMaxWidth(460);

        next = Ui.primary(CONTINUE);
        next.setDefaultButton(true);
        next.setOnAction(e -> submit());

        Label lead = new Label("Enter your National ID or Iqama number to begin.");
        lead.getStyleClass().add("lead");
        lead.setWrapText(true);
        Label leadAr = new Label("أدخل رقم الهوية الوطنية أو الإقامة للبدء");
        leadAr.getStyleClass().add("muted");
        Label demo = new Label("Prototype test IDs: 1000000001 - 1000000004, 2000000005");
        demo.getStyleClass().add("hint");

        VBox left = new VBox(16, lead, leadAr, field, error, next, demo);
        left.setAlignment(Pos.CENTER_LEFT);
        HBox.setHgrow(left, Priority.ALWAYS);

        HBox body = new HBox(48, left, keypad());
        body.setAlignment(Pos.CENTER_LEFT);

        Platform.runLater(field::requestFocus);
        return Ui.page(0, "Welcome to MediQueue", "مرحباً بك في ميدي كيو", body);
    }

    /** On-screen keypad for touchscreen kiosks (NFR-15). */
    private GridPane keypad() {
        GridPane grid = new GridPane();
        grid.setHgap(12);
        grid.setVgap(12);
        grid.getStyleClass().add("panel");
        String[] keys = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "Clear", "0", "Delete"};
        for (int i = 0; i < keys.length; i++) {
            String key = keys[i];
            Button b = new Button(key);
            b.getStyleClass().add("key");
            if (key.length() > 1) {
                b.getStyleClass().add("key-fn");
            }
            b.setFocusTraversable(false);
            b.setOnAction(e -> press(key));
            grid.add(b, i % 3, i / 3);
        }
        return grid;
    }

    private void press(String key) {
        String text = field.getText();
        switch (key) {
            case "Clear" -> field.clear();
            case "Delete" -> {
                if (!text.isEmpty()) {
                    field.setText(text.substring(0, text.length() - 1));
                }
            }
            default -> {
                if (text.length() < 10) {
                    field.setText(text + key);
                }
            }
        }
        field.positionCaret(field.getText().length());
    }

    private void submit() {
        Ui.hide(error);
        String id = field.getText();
        if (id.length() != 10) {
            Ui.showError(error, "Please enter all 10 digits of your ID.\nالرجاء إدخال رقم الهوية كاملاً (10 أرقام).");
            return;
        }
        setBusy(true);
        Ui.async(() -> app.service.validateAndGetPatient(id),
                patient -> {
                    app.patient = patient;
                    app.goClinics();
                },
                err -> {
                    setBusy(false);
                    Ui.showError(error, Ui.friendly(err));
                });
    }

    private void setBusy(boolean busy) {
        next.setDisable(busy);
        next.setText(busy ? "Checking..." : CONTINUE);
        field.setDisable(busy);
    }
}

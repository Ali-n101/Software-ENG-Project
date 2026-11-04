package UI;

import Util.DatabaseConnection;
import javafx.scene.Parent;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.control.PasswordField;
import javafx.scene.control.TextField;
import javafx.scene.layout.ColumnConstraints;
import javafx.scene.layout.GridPane;
import javafx.scene.layout.Priority;
import javafx.scene.layout.VBox;

import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Properties;

/** Staff-only screen: database login before the kiosk is handed to patients. */
class DbSetupView {
    private static final String CONNECT = "Connect and start kiosk";
    private final KioskApp app;

    DbSetupView(KioskApp app) {
        this.app = app;
    }

    Parent build() {
        Properties saved = loadProperties();

        TextField user = new TextField(saved.getProperty("db.user", "root"));
        user.getStyleClass().add("form-field");
        PasswordField pass = new PasswordField();
        pass.setText(saved.getProperty("db.password", ""));
        pass.getStyleClass().add("form-field");

        GridPane form = new GridPane();
        form.setHgap(16);
        form.setVgap(14);
        form.addRow(0, fieldLabel("MySQL username"), user);
        form.addRow(1, fieldLabel("MySQL password"), pass);
        ColumnConstraints labels = new ColumnConstraints();
        ColumnConstraints fields = new ColumnConstraints();
        fields.setHgrow(Priority.ALWAYS);
        form.getColumnConstraints().addAll(labels, fields);

        Label note = new Label("Staff setup: connect the kiosk to its database before patients use it.\n"
                + "Tip: put db.user and db.password in MediQueue/db.properties to fill these in automatically.");
        note.setWrapText(true);
        note.getStyleClass().add("muted");

        Label error = Ui.errorBanner();
        Button connect = Ui.primary(CONNECT);
        connect.setDefaultButton(true);
        connect.setOnAction(e -> {
            Ui.hide(error);
            connect.setDisable(true);
            connect.setText("Connecting...");
            DatabaseConnection.setCredentials(user.getText().trim(), pass.getText());
            Ui.async(() -> {
                DatabaseConnection.getConnection().close();
                return Boolean.TRUE;
            }, ok -> app.startOver(), err -> {
                connect.setDisable(false);
                connect.setText(CONNECT);
                Ui.showError(error, Ui.friendly(err));
            });
        });

        VBox panel = new VBox(20, note, form, error, connect);
        panel.getStyleClass().add("panel");
        panel.setMaxWidth(640);
        return Ui.page(-1, "Kiosk setup", "إعداد الجهاز", new VBox(panel));
    }

    private static Label fieldLabel(String text) {
        Label l = new Label(text);
        l.getStyleClass().add("field-label");
        return l;
    }

    private static Properties loadProperties() {
        Properties p = new Properties();
        for (String candidate : new String[] {"db.properties", "MediQueue/db.properties"}) {
            Path path = Paths.get(candidate);
            if (Files.exists(path)) {
                try (InputStream in = Files.newInputStream(path)) {
                    p.load(in);
                } catch (Exception ignored) {
                    // Fall back to manual entry.
                }
                break;
            }
        }
        return p;
    }
}

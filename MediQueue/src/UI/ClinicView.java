package UI;

import Model.Clinic;
import javafx.geometry.Pos;
import javafx.scene.Node;
import javafx.scene.Parent;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.control.ScrollPane;
import javafx.scene.layout.FlowPane;
import javafx.scene.layout.Priority;
import javafx.scene.layout.StackPane;
import javafx.scene.layout.VBox;

import java.util.List;

/** Step 2 - FR-03, FR-04: show active clinics and let the patient pick one. */
class ClinicView {
    private final KioskApp app;

    ClinicView(KioskApp app) {
        this.app = app;
    }

    Parent build() {
        Label lead = new Label("Choose the clinic you would like to visit.");
        lead.getStyleClass().add("lead");

        StackPane holder = new StackPane(Ui.loading("Loading clinics..."));
        holder.setAlignment(Pos.TOP_LEFT);
        VBox.setVgrow(holder, Priority.ALWAYS);

        Ui.async(() -> app.service.getClinics(),
                clinics -> holder.getChildren().setAll(clinics.isEmpty()
                        ? Ui.emptyState("No clinics are available right now.", "لا توجد عيادات متاحة حالياً")
                        : grid(clinics)),
                err -> holder.getChildren().setAll(Ui.errorState(Ui.friendly(err))));

        Button cancel = Ui.secondary("Cancel");
        cancel.setOnAction(e -> app.startOver());

        VBox body = new VBox(16, lead, holder);
        return Ui.page(1, "Hello, " + app.patient.getFullName(), "اختر العيادة", body, cancel);
    }

    private Node grid(List<Clinic> clinics) {
        FlowPane flow = new FlowPane(18, 18);
        for (Clinic clinic : clinics) {
            Label name = new Label(clinic.getName());
            name.getStyleClass().add("card-title");
            name.setWrapText(true);
            Label location = new Label(clinic.getLocation());
            location.getStyleClass().add("card-sub");
            location.setWrapText(true);

            Button card = new Button();
            card.setGraphic(new VBox(8, name, location));
            card.getStyleClass().add("clinic-card");
            card.setOnAction(e -> {
                app.clinic = clinic;
                app.goSlots();
            });
            flow.getChildren().add(card);
        }
        ScrollPane scroll = new ScrollPane(flow);
        scroll.setFitToWidth(true);
        return scroll;
    }
}

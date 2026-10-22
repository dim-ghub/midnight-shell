pragma Singleton

import QtQuick
import Caelestia.I18n
import Quickshell
import Caelestia
import Caelestia.Config

Singleton {
    id: root

    property bool loading: false
    property var results: []
    property string errorText: ""
    property int generation: 0

    function search(query: string): void {
        const token = ++generation;
        results = [];
        errorText = "";
        const term = query.trim();
        if (term.length < 2) {
            loading = false;
            errorText = Tr.tr("Enter at least two characters.");
            return;
        }
        loading = true;
        const language = (GlobalConfig.general.language || Qt.locale().name).split(/[_-]/)[0];
        const url = "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(term)
            + "&count=8&language=" + encodeURIComponent(language) + "&format=json";
        Requests.get(url, text => {
            if (token !== root.generation)
                return;
            try {
                const response = JSON.parse(text);
                if (response.error)
                    throw new Error(response.reason);
                root.results = (response.results || []).filter(place =>
                    place && typeof place.name === "string" && place.name.length > 0
                    && Number.isFinite(place.latitude) && Math.abs(place.latitude) <= 90
                    && Number.isFinite(place.longitude) && Math.abs(place.longitude) <= 180);
                if (!root.results.length)
                    root.errorText = Tr.tr("No matching cities. Try another name.");
            } catch (error) {
                root.errorText = Tr.tr("The city search returned an invalid response.");
            }
            root.loading = false;
        }, error => {
            if (token !== root.generation)
                return;
            root.errorText = Tr.tr("Unable to search for cities. Check your connection and try again.");
            root.loading = false;
        });
    }

    function clear(): void {
        generation++;
        loading = false;
        results = [];
        errorText = "";
    }
}

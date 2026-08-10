import PhotosUI
import SwiftUI
import UIKit

struct EstablishmentWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    private enum Step: Hashable {
        case brand
        case hub
        case details
        case address
        case photos
    }

    @State private var step: Step = .brand
    @State private var brands: [BrandSummary] = []
    @State private var selectedBrand: BrandSummary?
    @State private var organizationName = ""
    @State private var brandName = ""

    @State private var establishmentName = ""
    @State private var venueID: UUID?
    @State private var detailsComplete = false
    @State private var addressComplete = false
    @State private var photosComplete = false

    @State private var instagramHandle = ""
    @State private var descriptionText = ""
    @State private var selectedCategories: Set<String> = []
    @State private var customCategory = ""
    @State private var contactName = ""
    @State private var contactPhone = ""
    @State private var contactIsSelf = false

    @State private var isPhysical = true
    @State private var country = ""
    @State private var city = ""
    @State private var locationLabel = ""
    @State private var addressLine1 = ""
    @State private var addressLine2 = ""
    @State private var postalCode = ""
    @State private var latText = ""
    @State private var lngText = ""

    @State private var logoItem: PhotosPickerItem?
    @State private var logoData: Data?
    @State private var logoPreview: UIImage?
    @State private var galleryItems: [PhotosPickerItem] = []
    @State private var galleryData: [Data] = []
    @State private var galleryPreviews: [UIImage] = []

    @State private var isBusy = false
    @State private var localError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if let localError {
                        Label(localError, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MarviColor.tomato)
                    } else if let syncError = appState.lastSyncError, isBusy == false {
                        Label(syncError, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MarviColor.tomato)
                    }

                    switch step {
                    case .brand: brandStep
                    case .hub: hubStep
                    case .details: detailsStep
                    case .address: addressStep
                    case .photos: photosStep
                    }
                }
                .padding(16)
            }
            .background(MarviColor.surface.ignoresSafeArea())
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step != .brand {
                        Button(appState.t(.estWizardBack)) {
                            withAnimation { step = backStep }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(appState.t(.close)) { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await loadBrands() }
        .onChange(of: contactIsSelf) { _, isSelf in
            if isSelf {
                contactName = appState.profile.displayName
            }
        }
        .onChange(of: logoItem) { _, item in
            Task { await loadLogo(from: item) }
        }
        .onChange(of: galleryItems) { _, items in
            Task { await loadGallery(from: items) }
        }
    }

    private var navigationTitle: String {
        switch step {
        case .brand: appState.t(.estWizardBrandTitle)
        case .hub: appState.t(.estWizardHubTitle)
        case .details: appState.t(.estWizardDetailsTitle)
        case .address: appState.t(.estWizardAddressTitle)
        case .photos: appState.t(.estWizardPhotosTitle)
        }
    }

    private var backStep: Step {
        switch step {
        case .brand: .brand
        case .hub: .brand
        case .details, .address, .photos: .hub
        }
    }

    private var header: some View {
        SectionTitle(
            title: navigationTitle,
            subtitle: headerSubtitle
        )
    }

    private var headerSubtitle: String {
        switch step {
        case .brand: appState.t(.estWizardBrandSub)
        case .hub: appState.t(.estWizardHubSub)
        case .details: appState.t(.estWizardDetailsSub)
        case .address: appState.t(.estWizardAddressSub)
        case .photos: appState.t(.estWizardPhotosSub)
        }
    }

    // MARK: - Brand

    private var brandStep: some View {
        return VStack(alignment: .leading, spacing: 16) {
            if !brands.isEmpty {
                MarviCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(appState.t(.estWizardExistingBrands))
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(MarviColor.muted)

                        ForEach(brands) { brand in
                            Button {
                                selectedBrand = brand
                                withAnimation { step = .hub }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(brand.brandName)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(MarviColor.ink)
                                        Text(brand.organizationName)
                                            .font(.caption)
                                            .foregroundStyle(MarviColor.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(MarviColor.muted)
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            MarviCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(appState.t(.estWizardCreateBrand))
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(MarviColor.muted)

                    MarviTextField(
                        placeholder: appState.t(.estWizardOrgNamePh),
                        text: $organizationName,
                        autocapitalization: .words
                    )
                    MarviTextField(
                        placeholder: appState.t(.estWizardBrandNamePh),
                        text: $brandName,
                        autocapitalization: .words
                    )
                }
            }

            PrimaryActionButton(
                title: isBusy ? appState.t(.submitting) : appState.t(.continueAction),
                systemImage: "building.2.fill",
                isDisabled: !canCreateBrand || isBusy
            ) {
                Task { await createBrand() }
            }
        }
    }

    private var canCreateBrand: Bool {
        !organizationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !brandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Hub

    private var hubStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let selectedBrand {
                Text("\(selectedBrand.brandName) · \(selectedBrand.organizationName)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MarviColor.muted)
            }

            MarviCard {
                VStack(alignment: .leading, spacing: 14) {
                    MarviTextField(
                        placeholder: appState.t(.estWizardEstablishmentNamePh),
                        text: $establishmentName,
                        autocapitalization: .words
                    )
                    .disabled(venueID != nil)

                    if venueID == nil {
                        PrimaryActionButton(
                            title: isBusy ? appState.t(.submitting) : appState.t(.estWizardCreateDraft),
                            systemImage: "plus.circle.fill",
                            isDisabled: !canCreateDraft || isBusy
                        ) {
                            Task { await createDraft() }
                        }
                    }
                }
            }

            if venueID != nil {
                MarviCard {
                    VStack(spacing: 0) {
                        checklistRow(
                            title: appState.t(.estWizardDetailsTitle),
                            complete: detailsComplete,
                            icon: "text.alignleft"
                        ) { step = .details }

                        Divider().background(MarviColor.border)

                        checklistRow(
                            title: appState.t(.estWizardAddressTitle),
                            complete: addressComplete,
                            icon: "mappin.and.ellipse"
                        ) { step = .address }

                        Divider().background(MarviColor.border)

                        checklistRow(
                            title: appState.t(.estWizardPhotosTitle),
                            complete: photosComplete,
                            icon: "photo.on.rectangle"
                        ) { step = .photos }
                    }
                }

                PrimaryActionButton(
                    title: isBusy ? appState.t(.submitting) : appState.t(.estWizardSubmitReview),
                    systemImage: "paperplane.fill",
                    isDisabled: !canSubmit || isBusy
                ) {
                    Task { await submitForReview() }
                }
            }
        }
    }

    private var canCreateDraft: Bool {
        selectedBrand != nil
            && !establishmentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSubmit: Bool {
        venueID != nil && detailsComplete && addressComplete && photosComplete
    }

    private func checklistRow(
        title: String,
        complete: Bool,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(MarviColor.rose)
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MarviColor.ink)
                Spacer()
                Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(complete ? MarviColor.emerald : MarviColor.muted)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MarviColor.muted)
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Details

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            MarviCard {
                VStack(alignment: .leading, spacing: 14) {
                    MarviTextField(
                        placeholder: appState.t(.estWizardInstagramPh),
                        text: $instagramHandle,
                        autocapitalization: .never
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        TextEditor(text: $descriptionText)
                            .frame(minHeight: 90)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(MarviColor.ink)
                            .background(MarviColor.panelElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(MarviColor.border, lineWidth: 1)
                            )
                            .onChange(of: descriptionText) { _, value in
                                if value.count > 200 {
                                    descriptionText = String(value.prefix(200))
                                }
                            }

                        Text(appState.tf(.estWizardDescriptionCount, descriptionText.count))
                            .font(.caption2)
                            .foregroundStyle(MarviColor.muted)
                    }

                    Text(appState.t(.estWizardCategoriesLabel))
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(MarviColor.muted)

                    FlowChips(
                        options: BusinessCategoryCatalog.all.map { $0.label(for: appState.preferredLanguage) },
                        selection: $selectedCategories
                    )

                    MarviTextField(
                        placeholder: appState.preferredLanguage == .turkish
                            ? "Kategori yoksa buraya yazın"
                            : "Can't find it? Add your category",
                        text: $customCategory,
                        autocapitalization: .words
                    )

                    Button {
                        let value = customCategory.trimmingCharacters(in: .whitespacesAndNewlines)
                        if value.count >= 2 {
                            selectedCategories.insert(value)
                            customCategory = ""
                        }
                    } label: {
                        Label(
                            appState.preferredLanguage == .turkish ? "Kategori ekle" : "Add category",
                            systemImage: "plus.circle.fill"
                        )
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MarviColor.rose)
                    }
                    .buttonStyle(.plain)
                    .disabled(customCategory.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)

                    MarviTextField(
                        placeholder: appState.t(.estWizardContactNamePh),
                        text: $contactName,
                        autocapitalization: .words
                    )
                    .disabled(contactIsSelf)

                    MarviTextField(
                        placeholder: appState.t(.estWizardContactPhonePh),
                        text: $contactPhone,
                        autocapitalization: .never
                    )

                    Toggle(isOn: $contactIsSelf) {
                        Text(appState.t(.estWizardContactIsSelf))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MarviColor.ink)
                    }
                    .tint(MarviColor.rose)
                }
            }

            PrimaryActionButton(
                title: isBusy ? appState.t(.saving) : appState.t(.save),
                systemImage: "checkmark.circle.fill",
                isDisabled: !canSaveDetails || isBusy
            ) {
                Task { await saveDetails() }
            }
        }
    }

    private var canSaveDetails: Bool {
        let ig = instagramHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = contactName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = contactPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        return (ig.isEmpty || ig.count >= 2)
            && !desc.isEmpty
            && desc.count <= 200
            && !selectedCategories.isEmpty
            && !name.isEmpty
            && !phone.isEmpty
    }

    // MARK: - Address

    private var addressStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            MarviCard {
                VStack(alignment: .leading, spacing: 14) {
                    Picker(appState.t(.estWizardLocationType), selection: $isPhysical) {
                        Text(appState.t(.estWizardPhysical)).tag(true)
                        Text(appState.t(.estWizardOnline)).tag(false)
                    }
                    .pickerStyle(.segmented)

                    MarviTextField(
                        placeholder: appState.t(.estWizardCountryPh),
                        text: $country,
                        autocapitalization: .words
                    )
                    MarviTextField(
                        placeholder: appState.t(.estWizardCityPh),
                        text: $city,
                        autocapitalization: .words
                    )
                    MarviTextField(
                        placeholder: appState.t(.estWizardAreaPh),
                        text: $locationLabel,
                        autocapitalization: .words
                    )

                    if isPhysical {
                        MarviTextField(
                            placeholder: appState.t(.estWizardAddress1Ph),
                            text: $addressLine1,
                            autocapitalization: .words
                        )
                        MarviTextField(
                            placeholder: appState.t(.estWizardAddress2Ph),
                            text: $addressLine2,
                            autocapitalization: .words
                        )
                        MarviTextField(
                            placeholder: appState.t(.estWizardPostalPh),
                            text: $postalCode,
                            autocapitalization: .characters
                        )
                        MarviTextField(
                            placeholder: appState.t(.estWizardLatPh),
                            text: $latText,
                            autocapitalization: .never
                        )
                        .keyboardType(.numbersAndPunctuation)
                        MarviTextField(
                            placeholder: appState.t(.estWizardLngPh),
                            text: $lngText,
                            autocapitalization: .never
                        )
                        .keyboardType(.numbersAndPunctuation)
                    }
                }
            }

            PrimaryActionButton(
                title: isBusy ? appState.t(.saving) : appState.t(.estWizardConfirmAddress),
                systemImage: "mappin.circle.fill",
                isDisabled: !canSaveAddress || isBusy
            ) {
                Task { await saveAddress() }
            }
        }
    }

    private var canSaveAddress: Bool {
        let c = country.trimmingCharacters(in: .whitespacesAndNewlines)
        let cityTrim = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c.isEmpty, !cityTrim.isEmpty else { return false }
        if isPhysical {
            let line1 = addressLine1.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line1.isEmpty else { return false }
            return Double(latText.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
                && Double(lngText.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
        }
        return true
    }

    // MARK: - Photos

    private var photosStep: some View {
        let addLogoTitle = appState.t(.estWizardAddLogo)
        let addGalleryTitle = appState.t(.estWizardAddGallery)
        let galleryCountTitle = appState.tf(.estWizardGalleryCount, galleryPreviews.count)

        return VStack(alignment: .leading, spacing: 16) {
            MarviCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(appState.t(.estWizardLogoLabel))
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(MarviColor.muted)

                    PhotosPicker(selection: $logoItem, matching: .images) {
                        ZStack {
                            if let logoPreview {
                                Image(uiImage: logoPreview)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                MarviColor.panelElevated
                                Label(addLogoTitle, systemImage: "building.2")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MarviColor.rose)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Text(appState.t(.estWizardGalleryLabel))
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(MarviColor.muted)

                    PhotosPicker(selection: $galleryItems, maxSelectionCount: 8, matching: .images) {
                        Label(
                            galleryPreviews.isEmpty
                                ? addGalleryTitle
                                : galleryCountTitle,
                            systemImage: "photo.on.rectangle.angled"
                        )
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(MarviColor.rose)
                        .background(MarviColor.rose.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if !galleryPreviews.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(galleryPreviews.enumerated()), id: \.offset) { _, image in
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 88, height: 88)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                        }
                    }

                    Text(appState.t(.estWizardPhotosHint))
                        .font(.caption)
                        .foregroundStyle(MarviColor.muted)
                }
            }

            PrimaryActionButton(
                title: isBusy ? appState.t(.uploadingPhoto) : appState.t(.save),
                systemImage: "photo.badge.plus",
                isDisabled: !canSavePhotos || isBusy
            ) {
                Task { await savePhotos() }
            }
        }
    }

    private var canSavePhotos: Bool {
        logoData != nil && galleryData.count >= 3
    }

    // MARK: - Actions

    private func loadBrands() async {
        brands = await appState.fetchMyBrands()
        if brands.count == 1 {
            selectedBrand = brands.first
        }
    }

    private func createBrand() async {
        localError = nil
        isBusy = true
        let created = await appState.createOrganizationWithBrand(
            organizationName: organizationName,
            brandName: brandName
        )
        isBusy = false
        if let created {
            selectedBrand = created
            brands = await appState.fetchMyBrands()
            withAnimation { step = .hub }
        } else {
            localError = appState.lastSyncError
        }
    }

    private func createDraft() async {
        guard let selectedBrand else { return }
        localError = nil
        isBusy = true
        let id = await appState.createEstablishmentDraft(
            brandID: selectedBrand.brandID,
            establishmentName: establishmentName
        )
        isBusy = false
        if let id {
            venueID = id
        } else {
            localError = appState.lastSyncError
        }
    }

    private func saveDetails() async {
        guard let venueID else { return }
        localError = nil
        isBusy = true
        let input = EstablishmentDetailsInput(
            instagramHandle: instagramHandle,
            description: descriptionText,
            categories: Array(selectedCategories).sorted(),
            contactName: contactName,
            contactPhone: contactPhone,
            contactIsSelf: contactIsSelf,
            offerCategory: offerCategory(for: selectedCategories)
        )
        let ok = await appState.upsertEstablishmentDetails(venueID: venueID, input: input)
        isBusy = false
        if ok {
            detailsComplete = true
            withAnimation { step = .hub }
        } else {
            localError = appState.lastSyncError
        }
    }

    private func saveAddress() async {
        guard let venueID else { return }
        localError = nil
        isBusy = true
        let lat = Double(latText.trimmingCharacters(in: .whitespacesAndNewlines))
        let lng = Double(lngText.trimmingCharacters(in: .whitespacesAndNewlines))
        let input = EstablishmentAddressInput(
            isPhysical: isPhysical,
            country: country,
            city: city,
            locationLabel: locationLabel.isEmpty ? city : locationLabel,
            addressLine1: addressLine1,
            addressLine2: addressLine2,
            postalCode: postalCode,
            lat: isPhysical ? lat : nil,
            lng: isPhysical ? lng : nil
        )
        let ok = await appState.upsertEstablishmentAddress(venueID: venueID, input: input)
        isBusy = false
        if ok {
            addressComplete = true
            withAnimation { step = .hub }
        } else {
            localError = appState.lastSyncError
        }
    }

    private func savePhotos() async {
        guard let venueID, let logoData else { return }
        localError = nil
        isBusy = true
        let ok = await appState.upsertEstablishmentPhotos(
            venueID: venueID,
            logoData: logoData,
            galleryData: galleryData
        )
        isBusy = false
        if ok {
            photosComplete = true
            withAnimation { step = .hub }
        } else {
            localError = appState.lastSyncError
        }
    }

    private func submitForReview() async {
        guard let venueID else { return }
        localError = nil
        isBusy = true
        let ok = await appState.submitEstablishmentForReview(venueID: venueID)
        isBusy = false
        if ok {
            dismiss()
        } else {
            localError = appState.lastSyncError
        }
    }

    private func loadLogo(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        logoData = data
        logoPreview = image
    }

    private func loadGallery(from items: [PhotosPickerItem]) async {
        var dataList: [Data] = []
        var images: [UIImage] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { continue }
            dataList.append(data)
            images.append(image)
        }
        galleryData = dataList
        galleryPreviews = images
    }

    private func offerCategory(for categories: Set<String>) -> OfferCategory {
        guard let first = categories.sorted().first else { return .retail }
        return BusinessCategoryCatalog.offerCategory(for: first)
    }
}

private struct FlowChips: View {
    let options: [String]
    @Binding var selection: Set<String>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
            ForEach(options, id: \.self) { option in
                let selected = selection.contains(option)
                Button {
                    if selected {
                        selection.remove(option)
                    } else {
                        selection.insert(option)
                    }
                } label: {
                    Text(option)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(selected ? .white : MarviColor.ink)
                        .background(
                            selected
                                ? AnyShapeStyle(MarviGradient.brand)
                                : AnyShapeStyle(MarviColor.panelElevated)
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

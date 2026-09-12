import {createElement} from "@opendaw/lib-jsx"
import {IconSymbol} from "@opendaw/studio-enums"
import {Icon} from "@/ui/components/Icon"
import {RailSection} from "@/ui/dashboard/RailSection"
import {RailFooterLink} from "@/ui/dashboard/RailFooterLink"

// OTA fork: the contributor avatars were fetched from api.github.com on every dashboard load.
// Removed so the dashboard makes no requests outside this origin. The link to upstream remains.
export const Contributors = () => (
    <RailSection title={[<span>Contributors</span>, <Icon symbol={IconSymbol.Github}/>]}>
        <RailFooterLink href="https://github.com/andremichelle/openDAW/graphs/contributors">Thank you ♡</RailFooterLink>
    </RailSection>
)
